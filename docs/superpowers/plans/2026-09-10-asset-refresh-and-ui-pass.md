# Asset Refresh and UI Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land six independent art-and-UI changes from the 2026-09-10 asset drop: the intro cutscene's CGs and rounded dialogue panel, BookClockWidget's two-pose sweep, soft shadows on papers and cards, the rebuilt lobby money chip, the daily-login overhaul, and RunResult's S rank plus its win-backdrop fix.

**Architecture:** Each task is scene-and-Inspector work driven through the Godot AI MCP bridge, with source-text and instantiation tests in `tests/test_*.gd`. Two new theme variations are added to `ThemeFactory` and baked once, up front, so the consuming tasks find them already shipped. No visual is constructed at runtime and no `theme_override_*` is added.

**Tech Stack:** Godot 4.6 (mobile renderer, Vulkan), GDScript, Godot AI MCP (`test_run`, `scene_open`, `node_create`, `node_set_property`, `node_manage`, `script_patch`, `scene_save`, `editor_screenshot`), Python 3 + Pillow for asset downscaling.

**Spec:** `docs/superpowers/specs/2026-09-10-asset-refresh-and-ui-pass-design.md`

## Global Constraints

- **Never hand-edit a `.tscn` while the editor is attached.** Its in-memory copy wins and the next `scene_save` silently overwrites your text edit. Go through `scene_open` → `node_create` / `node_set_property` / `node_manage` → `scene_save`.
- **Scene work first, script work second.** `scene_save` flushes stale script buffers over whatever you patched. After any `scene_save`, run `git diff HEAD -- '*.gd'` and check for files you were not editing.
- **Rescan after editing a `.gd`, before running tests** — `test_run` serves a stale autoload otherwise. If the file was edited from outside the editor, a no-op `script_patch` on it (add and remove a blank line) forces the reload; it logs a benign `GDScript reload failed with error code 43` and then works.
- **Every test suite must be `@tool`.** No test may be a coroutine — the runner does `suite.call(name)` without awaiting, so an `await` silently aborts the test and reports "0 assertions".
- **A suite that calls `assert_not_null(` must `extends McpTestSuiteCompat`**, not `McpTestSuite`. Guarded by `test_every_non_null_assertion_caller_extends_the_compat_shim` in `tests/test_project_hygiene.gd`.
- **Never add a `theme_override_*`.** Use a `ThemeFactory` type variation. Only accepted exception: layout-only constant overrides (`separation`, `margin_*`).
- **No visual is built at runtime.** Static chrome is a node in the `.tscn`; repeated rows are a `PackedScene` template.
- **Game-facing identifiers and all UI text are Indonesian**; engine and systems code is English.
- **Never change `Scripts/Balance.gd`** — collaborator-owned. Read freely; propose, don't edit.
- **No emoji as UI iconography.** Use real transparent SVG/PNG textures.
- Commits use Conventional Commits with a scope, e.g. `fix(lobby): wire the dead ReportStudent button`.
- Some suites assume `Scenes/MainMenu/main_menu.tscn` is open in the editor; `test_run` returns a `scene_warning` naming the scene it wants when it isn't. Open it before trusting a failure.

---

### Task 1: Asset intake

Copy the new art into the repo, downscaling the four oversized sources. The project imports textures at `compress/mode=0` (lossless on disk, RGBA8 in VRAM), so a source's pixel dimensions are its VRAM cost. Untransformed, the seven daily-login panels alone would cost 658 MB.

**Files:**
- Create: `scripts_tmp/downscale_assets.py` (scratchpad — not committed)
- Create: `Assets/Images/UI/uang.png`, `Assets/Images/UI/icon_daily_login.png`
- Create: `Assets/Images/UI/DailyLogin/day1.png` … `day7.png`
- Create: `Assets/Images/EndGame/Ranks/rank_s.png`, `rank_a.png`, `rank_b.png`, `rank_c.png`, `rank_d.png`
- Modify: `Assets/Images/CG/cg2.jpg`, `Assets/Images/CG/cg4.jpg` (overwrite)
- Modify: `Assets/Images/SchoolDay/transition_background.png`, `transition_foreground.png` (overwrite)

**Interfaces:**
- Produces: the exact `res://` paths every later task references. Nothing consumes code from this task.

- [ ] **Step 1: Write the downscale script**

Straight LANCZOS on RGBA pulls whatever garbage RGB sits under fully transparent pixels into the edges, giving a dark or coloured fringe on the rounded corners. Premultiply, resize, unpremultiply.

Write to the scratchpad directory (`$SCRATCH` below is the session scratchpad path from the environment, not the repo):

```python
# downscale_assets.py
import numpy as np
from PIL import Image

def downscale_rgba(src, dst, size):
    """Resize a transparent PNG without alpha fringing."""
    arr = np.asarray(Image.open(src).convert("RGBA")).astype(np.float64)
    alpha = arr[..., 3:4] / 255.0
    arr[..., :3] *= alpha                     # premultiply
    pre = Image.fromarray(arr.astype(np.uint8), "RGBA").resize(size, Image.LANCZOS)
    out = np.asarray(pre).astype(np.float64)
    a2 = out[..., 3:4] / 255.0
    np.divide(out[..., :3], a2, out=out[..., :3], where=a2 > 0)   # unpremultiply
    out[..., :3] = out[..., :3].clip(0, 255)
    Image.fromarray(out.astype(np.uint8), "RGBA").save(dst, optimize=True)
    print("wrote", dst, size)
```

- [ ] **Step 2: Verify the source files are all present**

Run:

```bash
cd /c/Users/user/Downloads && ls -la "CG 2.jpg" "CG 4.jpg" transition_bakcground.png transition_foreground.png uang.png dailylogin.png day1.png day2.png day3.png day4.png day5.png day6.png day7.png rank_s.png rank_a.png rank_b.png rank_c.png rank_d.png
```

Expected: all 18 files listed, no "No such file". Note the source filename is `transition_bakcground.png` — the typo is in the source, not here.

- [ ] **Step 3: Copy the two JPG CGs and the foreground**

These are already at their target dimensions (CGs 1080×1920, foreground 1080×1920), so they are plain copies — no resample, no alpha handling.

```bash
cd "/c/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project" && cp "/c/Users/user/Downloads/CG 2.jpg" Assets/Images/CG/cg2.jpg && cp "/c/Users/user/Downloads/CG 4.jpg" Assets/Images/CG/cg4.jpg && cp /c/Users/user/Downloads/transition_foreground.png Assets/Images/SchoolDay/transition_foreground.png && cp /c/Users/user/Downloads/dailylogin.png Assets/Images/UI/icon_daily_login.png
```

- [ ] **Step 4: Downscale and place the rest**

```python
import os
D = "C:/Users/user/Downloads"
P = "C:/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project"
os.makedirs(f"{P}/Assets/Images/UI/DailyLogin", exist_ok=True)
os.makedirs(f"{P}/Assets/Images/EndGame/Ranks", exist_ok=True)

downscale_rgba(f"{D}/transition_bakcground.png",
               f"{P}/Assets/Images/SchoolDay/transition_background.png", (2048, 2048))
downscale_rgba(f"{D}/uang.png", f"{P}/Assets/Images/UI/uang.png", (256, 206))
for n in range(1, 8):
    downscale_rgba(f"{D}/day{n}.png",
                   f"{P}/Assets/Images/UI/DailyLogin/day{n}.png", (1600, 710))
for r in ["s", "a", "b", "c", "d"]:
    downscale_rgba(f"{D}/rank_{r}.png",
                   f"{P}/Assets/Images/EndGame/Ranks/rank_{r}.png", (512, 495))
```

- [ ] **Step 5: Verify every destination exists at the right size**

```bash
cd "/c/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project" && python -c "
from PIL import Image
want = {
 'Assets/Images/CG/cg2.jpg': (1080,1920), 'Assets/Images/CG/cg4.jpg': (1080,1920),
 'Assets/Images/SchoolDay/transition_background.png': (2048,2048),
 'Assets/Images/SchoolDay/transition_foreground.png': (1080,1920),
 'Assets/Images/UI/uang.png': (256,206),
 'Assets/Images/UI/icon_daily_login.png': (317,385),
}
for n in range(1,8): want['Assets/Images/UI/DailyLogin/day%d.png'%n]=(1600,710)
for r in 'sabcd': want['Assets/Images/EndGame/Ranks/rank_%s.png'%r]=(512,495)
bad=[]
for p,s in want.items():
    got=Image.open(p).size
    if got!=s: bad.append('%s got %s want %s'%(p,got,s))
print('MISMATCHES:', bad if bad else 'none')
"
```

Expected: `MISMATCHES: none`

- [ ] **Step 6: Import the new files into the editor**

Via MCP: `filesystem_manage(op="scan")`. Godot writes a `.import` sidecar for each new texture.

- [ ] **Step 7: Verify the editor imported them without error**

Via MCP: `logs_read(source="editor")`. Expected: no `Failed to import` or `Error opening file` lines naming any path from step 5. `source="game"` misses these entirely — it must be `editor`.

- [ ] **Step 8: Commit**

```bash
git add Assets/Images/CG/cg2.jpg Assets/Images/CG/cg4.jpg Assets/Images/SchoolDay Assets/Images/UI/uang.png Assets/Images/UI/uang.png.import Assets/Images/UI/icon_daily_login.png Assets/Images/UI/icon_daily_login.png.import Assets/Images/UI/DailyLogin Assets/Images/EndGame
git commit -m "feat(assets): bring in the 2026-09-10 art drop

CGs 2 and 4, the day-transition sky and foreground, the coin stack, the
daily-login calendar icon and its seven panels, and the five rank badges.

Four sources are downscaled on the way in: the project imports at
compress/mode=0, so source dimensions are VRAM cost, and the seven raw
daily-login panels alone would have cost 658 MB.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: Theme variations and rebake

Add the two new variations both consuming tasks need, and bake them once. Both are built only from tokens that already exist, so no new `DesignTokens` `@export` is added and no editor restart is needed.

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd`
- Modify: `tests/test_theme_factory.gd:316` (the `DISPLAY_ROSTER` const)
- Modify: `Assets/Theme/kejartes_theme.tres` (written by the bake, not by hand)
- Create then delete: `tests/test_zz_transient_rebake.gd`

**Interfaces:**
- Produces:
  - Theme type variation `"CutsceneDialogue"`, base `RichTextLabel`, `normal_font_size` = `tokens.font_title` (36), `default_color` = `tokens.text_primary`, body face. Consumed by Task 3.
  - Theme type variation `"GhostButton"`, base `Button`, `StyleBoxEmpty` for normal/focus/disabled, faint white washes for hover/pressed, display face, `font_color` = `tokens.text_primary`. Consumed by Task 8.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_theme_factory.gd`. That suite already `extends McpTestSuiteCompat`, and these use `assert_eq` / `assert_true` only, so no base-class change is needed.

```gdscript
## RichTextLabel reads "normal_font_size" and "default_color", NOT
## "font_size" and "font_color" -- those are Label/Button theme items, and
## setting them on a RichTextLabel variation is a silent no-op. The base
## RichTextLabel styling at ThemeFactory's _build_base_overrides already
## carries a comment about this; the same trap applies to the variation.
func test_cutscene_dialogue_is_bigger_body_text() -> void:
	var tokens := DesignTokens.load_default()
	assert_eq(_theme.get_font_size("normal_font_size", "CutsceneDialogue"),
		tokens.font_title,
		"cutscene dialogue steps up from body (28) to title (36)")
	assert_eq(_theme.get_color("default_color", "CutsceneDialogue"),
		tokens.text_primary,
		"and reads through default_color, not font_color")
	assert_eq(_theme.get_type_variation_base("CutsceneDialogue"),
		&"RichTextLabel",
		"it varies RichTextLabel, not Label")


## The daily-login claim button sits on top of the panel art's own gold
## pill, so the button must draw nothing of its own in the resting state.
func test_ghost_button_draws_no_resting_chrome() -> void:
	for state in ["normal", "focus", "disabled"]:
		assert_true(_theme.get_stylebox(state, "GhostButton") is StyleBoxEmpty,
			"GhostButton's %s state must draw nothing -- the art is the button"
				% state)
	assert_true(_theme.get_stylebox("hover", "GhostButton") is StyleBoxFlat,
		"but it still needs a touch affordance on hover")
	assert_true(_theme.get_stylebox("pressed", "GhostButton") is StyleBoxFlat,
		"and on press")
	assert_eq(_theme.get_type_variation_base("GhostButton"), &"Button",
		"it varies Button")
```

- [ ] **Step 2: Run the tests to verify they fail**

Via MCP: `test_run(suite="theme_factory")`.
Expected: FAIL — both new tests report a null/empty stylebox and a zero font size, because neither variation exists yet.

- [ ] **Step 3: Add the two variations to ThemeFactory**

In `Scripts/Design/ThemeFactory.gd`, add both functions and call them from `build()`. Add the calls inside the existing `_build_buttons` / `_build_labels` section calls — `_add_ghost_button` from `_build_buttons`, `_add_cutscene_dialogue` from `_build_labels`.

```gdscript
## The cutscene's dialogue text: one step up the scale from body, on the
## body face, over the Card panel Task 3 puts behind it.
##
## RichTextLabel's theme items are NOT the Label ones. Its size key is
## "normal_font_size" and its colour key is "default_color"; setting
## "font_size"/"font_color" here compiles and does nothing, which is the
## same trap _build_base_overrides already documents for the base type.
static func _add_cutscene_dialogue(theme: Theme, tokens: DesignTokens) -> void:
	const NAME := "CutsceneDialogue"
	theme.add_type(NAME)
	theme.set_type_variation(NAME, "RichTextLabel")
	theme.set_font_size("normal_font_size", NAME, tokens.font_title)
	theme.set_color("default_color", NAME, tokens.text_primary)


## A button with no chrome of its own, for sitting on top of art that
## already draws the button -- the daily-login panel's baked gold pill.
##
## Modelled on ShopHubTile, which solves the same problem for the shop
## hub's panel-less tiles: nothing in the resting state, and only the
## touch states wash in.
static func _add_ghost_button(theme: Theme, tokens: DesignTokens) -> void:
	const NAME := "GhostButton"
	theme.add_type(NAME)
	theme.set_type_variation(NAME, "Button")

	theme.set_stylebox("normal", NAME, StyleBoxEmpty.new())
	theme.set_stylebox("focus", NAME, StyleBoxEmpty.new())
	theme.set_stylebox("disabled", NAME, StyleBoxEmpty.new())

	var wash := StyleBoxFlat.new()
	wash.bg_color = Color(1, 1, 1, 0.14)
	wash.set_corner_radius_all(tokens.radius_pill)
	theme.set_stylebox("hover", NAME, wash)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0, 0, 0, 0.12)
	pressed.set_corner_radius_all(tokens.radius_pill)
	theme.set_stylebox("pressed", NAME, pressed)

	theme.set_font_size("font_size", NAME, tokens.font_h2)
	theme.set_color("font_color", NAME, tokens.text_primary)
	if tokens.font_display != null:
		theme.set_font("font", NAME, tokens.font_display)
```

- [ ] **Step 4: Add GhostButton to the display roster**

`GhostButton` sets the display face, and `test_display_font_roster_is_exact` checks both directions — it walks `_theme.get_type_list()` and flags anything carrying the display font that is not on the roster. `CutsceneDialogue` uses the body face and must **not** be added.

In `tests/test_theme_factory.gd`, inside `DISPLAY_ROSTER`, append before the closing `]`:

```gdscript
	# 2026-09-10: the daily-login claim button, display face over the
	# panel art's own gold pill.
	"GhostButton",
```

- [ ] **Step 5: Rescan, then run the theme suite**

There is no MCP entry point for an `EditorScript`, so the bake normally needs File > Run by hand. Before baking, confirm the factory itself is right.

Via MCP: `filesystem_manage(op="scan")`, then `test_run(suite="theme_factory")`.
Expected: the two new tests PASS; `test_baked_theme_matches_what_the_factory_builds` now FAILS, because the factory builds two types the shipped `.tres` lacks.

- [ ] **Step 6: Rebake the theme headlessly**

Create `tests/test_zz_transient_rebake.gd`:

```gdscript
@tool
extends McpTestSuite

## TRANSIENT. Drives Scripts/Design/BakeTheme.gd's work from inside the
## test runner, because there is no MCP entry point for an EditorScript.
## Delete this file as soon as the bake has run.

func suite_name() -> String:
	return "zz_transient_rebake"


func test_rebake() -> void:
	var theme := ThemeFactory.build(DesignTokens.load_default())
	var err := ResourceSaver.save(theme, "res://Assets/Theme/kejartes_theme.tres")
	assert_eq(err, OK, "the theme must save")
```

Via MCP: `filesystem_manage(op="scan")`, then `test_run(suite="zz_transient_rebake")`.
Expected: PASS.

- [ ] **Step 7: Delete the transient suite and confirm the bake landed**

```bash
cd "/c/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project" && rm tests/test_zz_transient_rebake.gd tests/test_zz_transient_rebake.gd.uid
```

Then via MCP: `filesystem_manage(op="scan")`, `test_run()` (whole suite).
Expected: all green, including `test_baked_theme_matches_what_the_factory_builds` and `test_display_font_roster_is_exact`.

- [ ] **Step 8: Check the bake did not strip UIDs**

`ResourceSaver.save()` run without the editor's UID cache rewrites the theme with every `uid://` stripped. Running it through the editor's own test runner should not, but verify:

```bash
cd "/c/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project" && git diff --stat Assets/Theme/kejartes_theme.tres && grep -c "uid://" Assets/Theme/kejartes_theme.tres
```

Expected: the diff is small (two variations added), and the `uid://` count is non-zero. If it dropped to 0, `git checkout -- Assets/Theme/kejartes_theme.tres` and rebake via File > Run instead.

- [ ] **Step 9: Commit**

```bash
git add Scripts/Design/ThemeFactory.gd tests/test_theme_factory.gd Assets/Theme/kejartes_theme.tres
git commit -m "feat(theme): add CutsceneDialogue and GhostButton variations

CutsceneDialogue steps the cutscene's dialogue from body (28) to title
(36) on the body face, through RichTextLabel's own normal_font_size and
default_color keys rather than the Label ones that read as no-ops.

GhostButton draws nothing at rest so art can be the button -- the
daily-login panel bakes its own gold claim pill. Modelled on ShopHubTile,
which solves the same problem for the shop hub.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Intro cutscene — rounded panel, bigger text, layout

The CGs already landed in Task 1 (`cut_scene.gd` preloads by path, so no code change was needed for them). This task replaces the dialogue box art with a themed rounded panel and fixes the layout.

`DialogueBox` currently spans y 940→2020 on a 1920-tall screen: 100 px hangs off the bottom edge.

**Files:**
- Modify: `Scenes/CutScene/cut_scene.tscn`
- Modify: `tests/test_cutscene.gd:123-158`

**Interfaces:**
- Consumes: `"CutsceneDialogue"` theme variation from Task 2.
- Produces: node path `DialogueBox/DialogueLabel` preserved — `cut_scene.gd:24` binds `$DialogueBox/DialogueLabel` and `:26` binds `$DialogueBox` as a `Control`.

- [ ] **Step 1: Rewrite the pinning tests**

`tests/test_cutscene.gd` currently hard-pins the box as a `TextureRect` drawing `cutscene_dialogue.png` at exact offsets 0/940/1080/2020. Replace that test and loosen the label bounds. That suite `extends McpTestSuite` and these use no `assert_not_null`, so the base class is unchanged.

Replace the existing `test_dialogue_box_draws_the_mockup_panel` (the block at lines 123–139) with:

```gdscript
## The mockup's panel art is gone: the box is now a themed rounded panel
## on the Card variation, so a colour or radius change in design_tokens
## reaches it like every other surface. It also no longer hangs 100px off
## the bottom of a 1920-tall screen, which the art-backed version did.
func test_dialogue_box_is_a_themed_rounded_panel() -> void:
	var box := _scene.find_child("DialogueBox", true, false) as Panel
	assert_true(box != null,
		"DialogueBox is missing or is no longer a Panel")
	assert_eq(box.theme_type_variation, &"Card",
		"DialogueBox must take its rounded chrome from the theme")
	assert_true(box.offset_bottom <= 1920.0,
		"the panel must sit inside the screen, got bottom %f" % box.offset_bottom)
	assert_true(box.offset_left >= 44.0,
		"and clear the screen margin on the left, got %f" % box.offset_left)
	assert_true(box.offset_right <= 1036.0,
		"and on the right, got %f" % box.offset_right)


## Retired with the art: nothing should still reference the panel PNG.
func test_the_mockup_panel_art_is_no_longer_referenced() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/CutScene/cut_scene.tscn")
	assert_false(src.contains("cutscene_dialogue.png"),
		"the panel is a theme variation now, not a texture")


func test_dialogue_text_uses_the_bigger_variation() -> void:
	var label := _scene.get_node_or_null(
		"DialogueBox/DialogueLabel") as RichTextLabel
	assert_true(label != null, "DialogueLabel is missing or is not a RichTextLabel")
	assert_eq(label.theme_type_variation, &"CutsceneDialogue",
		"the dialogue must take its larger size from the theme")
```

Then replace the label-bounds assertions (lines 147–152) with bounds relative to the new panel:

```gdscript
func test_dialogue_text_sits_inside_its_panel() -> void:
	var box := _scene.find_child("DialogueBox", true, false) as Control
	var label := _scene.get_node_or_null("DialogueBox/DialogueLabel") as Control
	assert_true(box != null and label != null, "panel and label must both exist")
	assert_true(label.offset_left >= 28.0,
		"text is inset from the panel's left edge, got %f" % label.offset_left)
	assert_true(label.offset_top >= 28.0,
		"and from its top, got %f" % label.offset_top)
	assert_true(label.offset_right <= box.size.x - 28.0,
		"and stops before its right edge")
	assert_true(label.offset_bottom <= box.size.y - 28.0,
		"and before its bottom")
```

- [ ] **Step 2: Run the tests to verify they fail**

Via MCP: `test_run(suite="cutscene")`.
Expected: FAIL — `DialogueBox is missing or is no longer a Panel` (it is still a `TextureRect`), and the variation assertions find empty `StringName`s.

- [ ] **Step 3: Rebuild the dialogue box in the editor**

A node's type can only be changed by delete-and-recreate. Via MCP, in order:

1. `scene_open("res://Scenes/CutScene/cut_scene.tscn")`
2. `node_manage(op="delete", path="DialogueBox")` — this takes `DialogueLabel` with it.
3. `node_create(type="Panel", name="DialogueBox", parent=".")`
4. `node_set_property` on `DialogueBox`:
   - `theme_type_variation` = `"Card"`
   - `layout_mode` = `0`
   - `offset_left` = `44`, `offset_top` = `1240`, `offset_right` = `1036`, `offset_bottom` = `1660`
   - `mouse_filter` = `2`
5. `node_create(type="RichTextLabel", name="DialogueLabel", parent="DialogueBox")`
6. `node_set_property` on `DialogueBox/DialogueLabel`:
   - `theme_type_variation` = `"CutsceneDialogue"`
   - `layout_mode` = `0`
   - `offset_left` = `44`, `offset_top` = `44`, `offset_right` = `948`, `offset_bottom` = `376`
   - `bbcode_enabled` = `true`
7. `node_set_property` on `HintLabel`: `offset_top` = `1700`, `offset_bottom` = `1760`
8. `node_manage(op="move", path="DialogueBox", to_index=1)` — `node_create` appends last, and the box must draw after `BgCutScene` but before `FadeOverlay`.
9. `scene_save()`

Numbers unquoted (`1240`, not `"1240.0"`), and `anchors_preset` is inert — these are plain offsets under `layout_mode = 0`, matching the rest of this scene.

- [ ] **Step 4: Check scene_save did not flush a stale script buffer**

```bash
cd "/c/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project" && git diff HEAD --stat -- '*.gd'
```

Expected: empty. If any `.gd` appears, the editor overwrote it from a stale tab — `git checkout --` those paths and redo.

- [ ] **Step 5: Run the tests to verify they pass**

Via MCP: `test_run(suite="cutscene")`.
Expected: PASS, including the existing `test_scene_has_no_theme_overrides`.

- [ ] **Step 6: Screenshot the cutscene**

Via MCP: `project_run()`, then use the debug overlay's Scenes tab to reach CutScene, then `editor_screenshot()`.

Confirm by eye: the panel sits fully inside the screen, its corners are rounded, the text is visibly larger than before, and `HintLabel` is clear of the panel. The new CG 2 and CG 4 should appear as the third and fifth beats.

- [ ] **Step 7: Commit**

```bash
git add Scenes/CutScene/cut_scene.tscn tests/test_cutscene.gd
git commit -m "feat(cutscene): themed rounded dialogue panel and larger text

The box was a TextureRect wearing cutscene_dialogue.png, sized 1080 tall
from y=940 -- 100px of it hung off the bottom of a 1920-tall screen. It is
now a Panel on the Card variation, inside the screen with token margins,
and the text steps from body (28) to title (36) via CutsceneDialogue.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: BookClockWidget — two poses, one sweep

The day currently rests at three authored poses (Dawn −90°, Midday −180°, Evening −270°) and `SchoolDay` drives it as two `transition_to()` calls with the event between them, so the sky freezes at Midday while the event popup is up. Collapse to two authored poses and one uninterrupted sweep.

The new textures already landed in Task 1 at the paths the scene points at, so no scene edit is needed here.

**Files:**
- Modify: `Scripts/SchoolSimulation/BookClockWidget.gd`
- Modify: `Scripts/SchoolSimulation/SchoolDay.gd:104-109, 388-392, 405-412`
- Modify: `tests/test_book_clock_phases.gd`

**Interfaces:**
- Consumes: `Assets/Images/SchoolDay/transition_background.png` and `transition_foreground.png` from Task 1.
- Produces: `BookClockWidget.dawn_rotation_degrees` (−90.0) and `evening_rotation_degrees` (−270.0) remain `@export`. `midday_rotation_degrees` is **gone**. `Phase.MIDDAY` stays in the enum and still maps to progress 0.5; `transition_to(phase, duration) -> Tween` is unchanged.

- [ ] **Step 1: Rewrite the pose tests**

In `tests/test_book_clock_phases.gd` (already `extends McpTestSuiteCompat`), replace the five midday-dependent tests. Update the suite docstring's first paragraph to:

```gdscript
## The school day was one continuous sweep, then three named poses with
## the event pinned to midday, and is now two poses and one uninterrupted
## sweep: the sky no longer rests mid-day while the event popup is up.
```

Replace `test_three_poses_are_exports_not_magic_numbers`:

```gdscript
func test_both_poses_are_exports_not_magic_numbers() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	for knob in ["dawn_rotation_degrees", "evening_rotation_degrees"]:
		assert_contains(src, "@export var %s" % knob,
			"each pose must be tunable in the Inspector")


func test_retired_the_midday_pose() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	assert_false(src.contains("midday_rotation_degrees"),
		"the midday angle is derived from the arc now, not authored")
```

Replace `test_each_pose_sits_on_the_sky_it_is_named_for`:

```gdscript
func test_each_pose_sits_on_the_sky_it_is_named_for() -> void:
	var w := _widget()
	assert_eq(w.dawn_rotation_degrees, -90.0, "dawn should be morning breaking")
	assert_eq(w.evening_rotation_degrees, -270.0, "evening should be dusk")
	w.free()
```

Replace `test_the_day_still_sweeps_counter_clockwise`:

```gdscript
func test_the_day_still_sweeps_counter_clockwise() -> void:
	var w := _widget()
	assert_true(w.evening_rotation_degrees < w.dawn_rotation_degrees,
		"evening must sit further counter-clockwise than dawn")
	w.free()
```

Replace `test_set_phase_snaps_the_sky_to_each_pose`:

```gdscript
func test_set_phase_snaps_the_sky_to_each_pose() -> void:
	var w := _widget()
	var sky := w.get_node("SkyBackground") as Control
	w.set_phase(BookClockWidget.Phase.DAWN)
	assert_true(is_equal_approx(sky.rotation_degrees, w.dawn_rotation_degrees),
		"DAWN should place the sky at its dawn angle")
	w.set_phase(BookClockWidget.Phase.EVENING)
	assert_true(is_equal_approx(sky.rotation_degrees, w.evening_rotation_degrees),
		"EVENING should place the sky at its evening angle")
	w.free()
```

Replace `test_set_progress_still_maps_through_the_midday_pose` and delete `test_midday_pose_can_be_moved_independently` entirely, in favour of:

```gdscript
func test_the_arc_is_one_straight_lerp_between_the_two_poses() -> void:
	# With midday gone, progress 0.5 is the arithmetic middle of the arc
	# by construction rather than a separately authored angle.
	var w := _widget()
	w.set_progress(0.5)
	var want := (w.dawn_rotation_degrees + w.evening_rotation_degrees) * 0.5
	assert_true(is_equal_approx(w.current_rotation_degrees(), want),
		"progress 0.5 should sit halfway along the arc, got %f want %f"
			% [w.current_rotation_degrees(), want])
	w.free()
```

Add a test for the single sweep:

```gdscript
func test_schoolday_sweeps_the_sky_once_across_the_whole_day() -> void:
	# The sky used to be handed two transitions with the event between
	# them, so it visibly froze at midday behind the popup. One call now,
	# spanning both phases.
	var src := FileAccess.get_file_as_string(SCHOOLDAY_SCRIPT)
	assert_eq(src.count("\"transition_to\""), 1,
		"the sky is swept exactly once per day")
	assert_false(src.contains("BookClockWidget.Phase.MIDDAY"),
		"nothing drives the sky to a midday pose any more")
```

Leave `test_transition_to_returns_its_tween_so_schoolday_can_await_it` alone but change its `Phase.MIDDAY` argument to `Phase.EVENING`.

- [ ] **Step 2: Run the tests to verify they fail**

Via MCP: `test_run(suite="book_clock_phases")`.
Expected: FAIL — `midday_rotation_degrees` is still in the source, and `SchoolDay` still contains two `"transition_to"` call sites.

- [ ] **Step 3: Collapse the widget to two poses**

In `Scripts/SchoolSimulation/BookClockWidget.gd`, delete the whole `midday_rotation_degrees` `@export` block (declaration, docstring and setter), and replace `current_rotation_degrees()`:

```gdscript
## The sky's angle, in degrees, for the current progress.
##
## One straight lerp between the day's two poses. This was piecewise
## through a third, separately authored midday angle until 2026-09-10;
## the middle of the day is now the middle of the arc by construction.
func current_rotation_degrees() -> float:
	return lerpf(dawn_rotation_degrees, evening_rotation_degrees, eased_progress())
```

Then simplify `angle_for_phase()`, which can no longer answer for MIDDAY from an authored value:

```gdscript
## The angle one phase rests at. MIDDAY has no authored angle of its own
## any more -- it is simply the arc's midpoint.
func angle_for_phase(phase: Phase) -> float:
	match phase:
		Phase.MIDDAY:
			return lerpf(dawn_rotation_degrees, evening_rotation_degrees, 0.5)
		Phase.EVENING:
			return evening_rotation_degrees
		_:
			return dawn_rotation_degrees
```

Update the file's header docstring: replace the "The day's three resting poses" line above `enum Phase` with:

```gdscript
## The day's two resting poses, plus MIDDAY as the arc's midpoint -- the
## event still rolls there, but the sky no longer stops for it.
```

- [ ] **Step 4: Make SchoolDay sweep once**

In `Scripts/SchoolSimulation/SchoolDay.gd`:

Replace the `EVENT_TRIGGER_PCT` docstring (lines 102–109):

```gdscript
## Where in the school day the event rolls, as a percentage of it.
##
## The day's progress bar still fills in two phases with the event between
## them, but the sky is swept once across both -- so the event lands at
## the middle of the day without the sky stopping there. It was pinned to
## a named midday pose until 2026-09-10, and to a randomised afternoon
## point before that.
const EVENT_TRIGGER_PCT := 50.0
```

Replace the phase-1 sweep call (the `if book_clock_widget and book_clock_widget.has_method("transition_to")` block at ~line 390) with a single full-day sweep, and delete the phase-2 block at ~line 410 entirely:

```gdscript
	# One sweep across the whole day. The sky is deliberately NOT paused
	# for the event: it used to rest at a midday pose while the popup was
	# up, which read as the day stopping. Because the event is
	# player-blocking, a slow player will see the sky reach evening before
	# the day's second half finishes and hold there -- accepted.
	if book_clock_widget and book_clock_widget.has_method("transition_to"):
		book_clock_widget.call("transition_to", BookClockWidget.Phase.EVENING,
			phase1_dur + _phase_duration())
```

Leave `phase2_dur := _phase_duration()` where it is — the progress bar still needs it, and `test_schoolday_paces_both_phases_off_the_clock` asserts `src.count(":= _phase_duration()") == 2`.

- [ ] **Step 5: Rescan and run the tests**

Via MCP: `filesystem_manage(op="scan")`, then `test_run(suite="book_clock_phases")`.
Expected: PASS.

If a test still reports the old source text, the editor is serving stale bytecode — force a reload with a no-op `script_patch` on the file (add and remove a blank line). It logs `GDScript reload failed with error code 43` and then works.

- [ ] **Step 6: Run the whole suite**

Via MCP: `test_run()`.
Expected: all green. `test_school_day*` suites are the likely collateral — check them specifically if anything fails.

- [ ] **Step 7: Screenshot a full sweep**

This is the check for the stray layer in the new sky source: a night street scene is pasted into its bottom-left corner. Measured at ~2480 source texels from centre against a ~1960-texel visible radius, so it should stay outside frame — but that margin depends on `sky_pivot_ratio` and `sky_cover_margin` holding.

Via MCP: `project_run()`, seed with the debug overlay's ⚡ Seed Playtest State, pass through Atur Jadwal (the seed does not fill `day_schedules`), then run a school day and `editor_screenshot()` at roughly dawn, midday and evening.

Confirm: no street scene, no hard rectangular edge, and no uncovered corner at any point in the sweep.

- [ ] **Step 8: Commit**

```bash
git add Scripts/SchoolSimulation/BookClockWidget.gd Scripts/SchoolSimulation/SchoolDay.gd tests/test_book_clock_phases.gd
git commit -m "feat(schoolday): sweep the sky once across the day

The day rested at three authored poses and the sky froze at midday while
the event popup was up. Midday is no longer an authored angle -- the arc
is one lerp between dawn and evening, and SchoolDay sweeps it once across
both phases. The event still rolls at 50%, the bar still fills in two
phases, and the total half-turn is unchanged.

Accepted consequence: the event is player-blocking, so a slow player sees
the sky reach evening early and hold.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: Soft shadow on the report card's papers

`report_card.tscn` has the same six-`KertasMurid` structure on the same `card_bg.png` as `student_card.tscn`, which already carries a shadow as of commit `ddc5903`. Give it the same treatment.

**Files:**
- Modify: `Scenes/ReportCard/report_card.tscn`
- Modify: `tests/test_report_card.gd`

**Interfaces:**
- Consumes: `Scripts/Shaders/soft_shadow_material.tres` (`uid://dv5bscxw2v678`), committed in `ddc5903`.
- Produces: a `Shadow` `TextureRect` as the first child after `Backdrop`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_report_card.gd`. It `extends McpTestSuite`; the test below uses no `assert_not_null`, so leave the base class alone. The assertion shape is copied from the established `tests/test_day_sticky_note.gd:31-36`.

```gdscript
## The papers sit on a wood desk with nothing lifting them off it. A
## sibling TextureRect wearing the same soft_shadow material DayStickyNote
## uses, drawn behind the card stack, blurs card_bg.png's own alpha
## silhouette so the edge goes soft while the fill stays flat.
func test_the_paper_stack_casts_a_soft_shadow() -> void:
	var scene = load(_SCENE_PATH).instantiate()
	var shadow := scene.get_node_or_null("Shadow") as TextureRect
	var is_shader: bool = shadow != null and shadow.material is ShaderMaterial
	var behind: bool = shadow != null \
		and shadow.get_index() < scene.get_node("KertasMurid6").get_index()
	var tinted: bool = shadow != null and shadow.self_modulate.a < 1.0
	scene.free()
	assert_true(shadow != null, "report_card.tscn needs a Shadow TextureRect")
	assert_true(is_shader, "Shadow needs the soft_shadow ShaderMaterial")
	assert_true(behind, "Shadow must draw behind the paper stack")
	assert_true(tinted, "Shadow must be a translucent tint, not opaque")
```

- [ ] **Step 2: Run the test to verify it fails**

Via MCP: `test_run(suite="report_card")`.
Expected: FAIL with `report_card.tscn needs a Shadow TextureRect`.

- [ ] **Step 3: Read the paper geometry so the shadow lines up**

Do not copy `student_card.tscn`'s offsets blind — confirm against this scene's own papers.

```bash
cd "/c/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project" && sed -n "$(grep -n 'node name="KertasMurid6"' Scenes/ReportCard/report_card.tscn | cut -d: -f1),+10p" Scenes/ReportCard/report_card.tscn
```

Note the `offset_*` values. The shadow uses the same rect, nudged down and out.

- [ ] **Step 4: Add the shadow node in the editor**

Via MCP, in order:

1. `scene_open("res://Scenes/ReportCard/report_card.tscn")`
2. `node_create(type="TextureRect", name="Shadow", parent=".")`
3. `node_set_property` on `Shadow`:
   - `texture` → `res://Assets/Images/StudentCard/card_bg.png`
   - `material` → `res://Scripts/Shaders/soft_shadow_material.tres`
   - `self_modulate` = `Color(0, 0, 0, 0.33)`
   - `layout_mode` = `0`
   - the four `offset_*` from step 3, each shifted by roughly `+8` on top/bottom and `−8`/`+8` on left/right
   - `scale` = `Vector2(1.03, 1.03)`
   - `mouse_filter` = `2`
4. `node_manage(op="move", path="Shadow", to_index=1)` — `node_create` appends last; it must sit after `Backdrop` and before `KertasMurid6`.
5. `scene_save()`

- [ ] **Step 5: Check scene_save did not flush a stale script buffer**

```bash
cd "/c/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project" && git diff HEAD --stat -- '*.gd'
```

Expected: empty.

- [ ] **Step 6: Run the test to verify it passes**

Via MCP: `test_run(suite="report_card")`.
Expected: PASS.

- [ ] **Step 7: Screenshot to check alignment**

Via MCP: `project_run()`, seed, teleport to Lobby, tap Rapor, `editor_screenshot()`.

Confirm: the shadow reads as one soft edge under the paper, offset consistently — not a visible second card peeking out on one side.

- [ ] **Step 8: Commit**

```bash
git add Scenes/ReportCard/report_card.tscn tests/test_report_card.gd
git commit -m "feat(reportcard): lift the paper stack off the desk

Same soft_shadow sibling student_card.tscn and DayStickyNote already use:
a translucent TextureRect behind the stack, blurring card_bg.png's alpha
silhouette so the edge softens and the fill stays flat.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: Soft shadows on the minigame cards

`QuestionCard.tscn` and `AnswerCard.tscn` already carry a `StyleBoxFlat` shadow at `0.12` alpha / `4` px, which barely registers. `PilihanGanda`'s three `@export` StyleBox slots are null, so its choice buttons fall through to the theme's dark ink — which that script's own docstring at line 108-110 flags as wrong.

`StyleBoxFlat` is the right tool here: these are theme/StyleBox-driven cards with no texture alpha for the shader to blur.

**Files:**
- Modify: `Scenes/Minigames/Akademis/QuestionCard.tscn`
- Modify: `Scenes/Minigames/Akademis/AnswerCard.tscn`
- Modify: `Scenes/Minigames/Akademis/PilihanGanda.tscn`
- Create: `tests/test_minigame_card_shadows.gd`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: nothing later tasks consume.

- [ ] **Step 1: Write the failing test**

Create `tests/test_minigame_card_shadows.gd`. It uses `assert_not_null`, so it **must** `extends McpTestSuiteCompat`.

```gdscript
@tool
extends McpTestSuiteCompat

## Every card in the two Akademis minigames casts a shadow deep enough to
## read as lifted.
##
## StyleBoxFlat rather than the soft_shadow shader: these are StyleBox-
## driven panels and buttons with no texture alpha for the shader to blur.
##
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "minigame_card_shadows"


const QUESTION_CARD := "res://Scenes/Minigames/Akademis/QuestionCard.tscn"
const ANSWER_CARD := "res://Scenes/Minigames/Akademis/AnswerCard.tscn"
const PILIHAN_GANDA := "res://Scenes/Minigames/Akademis/PilihanGanda.tscn"

## Floors, not exact values -- the look is tunable, the presence is not.
const MIN_SHADOW_ALPHA := 0.18
const MIN_SHADOW_SIZE := 8


func _panel_box(scene_path: String) -> StyleBoxFlat:
	var card = load(scene_path).instantiate()
	var box := card.get_theme_stylebox("panel") as StyleBoxFlat
	card.free()
	return box


func test_the_question_card_casts_a_readable_shadow() -> void:
	var box := _panel_box(QUESTION_CARD)
	assert_not_null(box, "QuestionCard's root must carry a StyleBoxFlat panel")
	assert_true(box.shadow_color.a >= MIN_SHADOW_ALPHA,
		"shadow alpha %f is below the %f floor" % [box.shadow_color.a, MIN_SHADOW_ALPHA])
	assert_true(box.shadow_size >= MIN_SHADOW_SIZE,
		"shadow size %d is below the %d floor" % [box.shadow_size, MIN_SHADOW_SIZE])
	assert_true(box.shadow_offset.y > 0.0,
		"the shadow falls downward, so the card reads as lifted")


func test_the_answer_card_casts_a_readable_shadow() -> void:
	var box := _panel_box(ANSWER_CARD)
	assert_not_null(box, "AnswerCard's root must carry a StyleBoxFlat panel")
	assert_true(box.shadow_color.a >= MIN_SHADOW_ALPHA,
		"shadow alpha %f is below the %f floor" % [box.shadow_color.a, MIN_SHADOW_ALPHA])
	assert_true(box.shadow_size >= MIN_SHADOW_SIZE,
		"shadow size %d is below the %d floor" % [box.shadow_size, MIN_SHADOW_SIZE])
	assert_true(box.shadow_offset.y > 0.0,
		"the shadow falls downward, so the card reads as lifted")


## All three states, not just normal: PilihanGanda swaps between them when
## the player answers, and a shadow on only one would flicker at that swap.
func test_every_choice_button_state_carries_the_same_shadow() -> void:
	var screen = load(PILIHAN_GANDA).instantiate()
	var boxes := {
		"normal": screen.answer_btn_normal_style,
		"correct": screen.answer_btn_correct_style,
		"wrong": screen.answer_btn_wrong_style,
	}
	var report := {}
	for key in boxes:
		var b = boxes[key]
		report[key] = {
			"is_flat": b is StyleBoxFlat,
			"alpha": (b.shadow_color.a if b is StyleBoxFlat else -1.0),
			"size": (b.shadow_size if b is StyleBoxFlat else -1),
		}
	screen.free()
	for key in report:
		assert_true(report[key]["is_flat"],
			"answer_btn_%s_style must be an authored StyleBoxFlat, not null" % key)
		assert_true(report[key]["alpha"] >= MIN_SHADOW_ALPHA,
			"%s shadow alpha %f is below the floor" % [key, report[key]["alpha"]])
		assert_true(report[key]["size"] >= MIN_SHADOW_SIZE,
			"%s shadow size %d is below the floor" % [key, report[key]["size"]])
```

- [ ] **Step 2: Run the test to verify it fails**

Via MCP: `filesystem_manage(op="scan")`, then `test_run(suite="minigame_card_shadows")`.
Expected: FAIL — the two cards report alpha `0.12` and size `4` (below both floors), and all three PilihanGanda styles report `is_flat: false` because they are null.

- [ ] **Step 3: Deepen the two card shadows**

Both roots are `PanelContainer`s carrying `theme_override_styles/panel = SubResource(...)` — an inline `StyleBoxFlat`. These are scenes the design system explicitly scopes out (minigames inherit the Theme but had no polish pass), so editing the override in place is correct here — do **not** migrate them to theme variations.

Via MCP, for each of `QuestionCard.tscn` and `AnswerCard.tscn`: `scene_open(<path>)`, then set three fields on the root's panel stylebox, then `scene_save()`.

Prefer `node_set_property` with an indexed sub-property path, which edits the existing sub-resource in place:

- `theme_override_styles/panel:shadow_color` = `Color(0, 0, 0, 0.22)`
- `theme_override_styles/panel:shadow_size` = `12`
- `theme_override_styles/panel:shadow_offset` = `Vector2(0, 6)`

If the bridge rejects the `:` sub-path, fall back to replacing the whole stylebox — every other field must be carried over unchanged. Current values, read from the scenes:

| Field | QuestionCard | AnswerCard |
|---|---|---|
| `bg_color` | `Color(0.98, 0.98, 0.98, 1)` | `Color(0.95, 0.97, 1, 1)` |
| `border_color` | `Color(0.85, 0.45, 0.1, 1)` | `Color(0.2, 0.5, 0.85, 1)` |
| `border_width_*` (all four) | `2` | `2` |
| `corner_radius_*` (all four) | `24` | `24` |
| `content_margin_left`/`right` | `8` | `8` |
| `content_margin_top`/`bottom` | `6` | `6` |

- [ ] **Step 4: Author PilihanGanda's three choice styles**

Via MCP: `scene_open("res://Scenes/Minigames/Akademis/PilihanGanda.tscn")`, then on the root `PilihanGanda` node set the three `@export` StyleBox properties to new `StyleBoxFlat` sub-resources. Shared across all three:

- `corner_radius_*` = `24` on all four corners
- `border_width_*` = `2` on all four sides
- `content_margin_left`/`right` = `20`, `top`/`bottom` = `14`
- `shadow_color` = `Color(0, 0, 0, 0.22)`, `shadow_size` = `12`, `shadow_offset` = `Vector2(0, 6)`

Per-state fills, light so the theme's own dark button ink reads on them — which is what the script's docstring asks for:

| Property | `answer_btn_normal_style` | `answer_btn_correct_style` | `answer_btn_wrong_style` |
|---|---|---|---|
| `bg_color` | `Color(0.98, 0.96, 0.91, 1)` | `Color(0.85, 0.95, 0.83, 1)` | `Color(0.97, 0.85, 0.84, 1)` |
| `border_color` | `Color(0.85, 0.45, 0.10, 1)` | `Color(0.30, 0.62, 0.28, 1)` | `Color(0.78, 0.26, 0.24, 1)` |

Then `scene_save()`.

- [ ] **Step 5: Check scene_save did not flush a stale script buffer**

```bash
cd "/c/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project" && git diff HEAD --stat -- '*.gd'
```

Expected: empty.

- [ ] **Step 6: Run the test to verify it passes**

Via MCP: `test_run(suite="minigame_card_shadows")`.
Expected: PASS.

- [ ] **Step 7: Confirm the ratchet did not move**

Both minigames are already on `tests/test_viewport_editability.gd`'s `BASELINE` (`Menjodohkan.gd`: 2, `PilihanGanda.gd`: 1). All work here is `.tscn` and Inspector, so the counts must be unchanged.

Via MCP: `test_run(suite="viewport_editability")`.
Expected: PASS with no baseline drift reported.

- [ ] **Step 8: Screenshot both minigames**

Via MCP: `project_run()`, launch each from the debug overlay's minigame launcher, `editor_screenshot()`.

Confirm: choice buttons are light with dark readable text (not the old dark-ink-on-dark), and every card sits visibly off its background.

- [ ] **Step 9: Commit**

```bash
git add Scenes/Minigames/Akademis/QuestionCard.tscn Scenes/Minigames/Akademis/AnswerCard.tscn Scenes/Minigames/Akademis/PilihanGanda.tscn tests/test_minigame_card_shadows.gd
git commit -m "feat(minigames): give every card a shadow that reads

The matching cards shipped a 0.12-alpha 4px shadow that was invisible;
deepened to 0.22/12/(0,6). PilihanGanda's three choice-button StyleBox
slots were null, so its buttons fell through to the theme's dark ink --
the exact fallback its own docstring warns against. Authored as light
rounded boxes carrying the same shadow, all three states so the swap on
answer does not flicker.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 7: Lobby money chip and shop coin icons

`DisplayUang` is a `TextureRect` at 332×187 wearing `Assets/Images/UI/Desain tanpa judul.png` — a 1920×1080 pink/magenta landscape image, with the money `Label` on top. The project guide lists it as debt on both counts.

**Files:**
- Modify: `Scenes/Lobby/loby.tscn` (the `DisplayUang` block at line 386)
- Modify: `Scenes/Koperasi/koprasi.tscn:280`
- Modify: `Scenes/Inventory/inventory.tscn:72`
- Modify: `tests/test_lobby.gd:196`
- Modify: `CLAUDE.md` (delete the resolved debt entry)

**Interfaces:**
- Consumes: `Assets/Images/UI/uang.png` from Task 1.
- Produces: node path `DisplayUang/Label` **preserved** — `loby.gd:57` binds `$DisplayUang/Label`, and `tests/test_lobby.gd` asserts it at lines 114 and 196.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_lobby.gd` (it `extends McpTestSuite`; no `assert_not_null` below, so leave that alone):

```gdscript
## The money readout was a 1920x1080 pink landscape PNG with a label on
## top -- off-palette, and the reason the chip was 332x187 rather than the
## 332x96 the layout wanted. It is a themed rounded panel now, with the
## coin as a real icon beside the number.
func test_the_money_chip_is_a_themed_panel_with_a_coin_icon() -> void:
	var chip := _lobby.get_node_or_null("DisplayUang") as Panel
	assert_true(chip != null, "DisplayUang must be a Panel now, not a TextureRect")
	assert_eq(chip.theme_type_variation, &"Card",
		"the chip takes its chrome from the theme")
	assert_eq(chip.size.y, 96.0,
		"the chip is 96 tall, matching DailyLogin, got %f" % chip.size.y)

	var icon := _lobby.get_node_or_null("DisplayUang/CoinIcon") as TextureRect
	assert_true(icon != null, "the chip needs a coin icon")
	assert_eq(icon.texture.resource_path, "res://Assets/Images/UI/uang.png",
		"and it is the new coin art")


func test_the_off_palette_chip_art_is_gone() -> void:
	var src := FileAccess.get_file_as_string("res://Scenes/Lobby/loby.tscn")
	assert_false(src.contains("Desain tanpa judul.png"),
		"the pink chip background must no longer be referenced")


## Both shop screens read the same coin as the lobby, so money looks like
## one currency across the game.
func test_the_shop_screens_use_the_same_coin() -> void:
	for path in ["res://Scenes/Koperasi/koprasi.tscn",
			"res://Scenes/Inventory/inventory.tscn"]:
		var src := FileAccess.get_file_as_string(path)
		assert_true(src.contains("Assets/Images/UI/uang.png"),
			"%s should show the shared coin" % path)
```

Then update the existing `test_labels_use_theme_variations` — change the money-label assertion from `BarLabel` to `CoinLabel`:

```gdscript
	var money := _lobby.get_node_or_null("DisplayUang/Label") as Label
	assert_true(money != null, "missing money label")
	assert_eq(money.theme_type_variation, &"CoinLabel", "money label variation")
```

- [ ] **Step 2: Run the tests to verify they fail**

Via MCP: `test_run(suite="lobby")`.
Expected: FAIL — `DisplayUang must be a Panel now, not a TextureRect`, and the variation assertion still finds `BarLabel`.

- [ ] **Step 3: Rebuild the chip in the editor**

A node's type can only be changed by delete-and-recreate, and `DisplayUang/Label` must come back at exactly that path. Children are positioned absolutely rather than wrapped in an `HBoxContainer` — both because the path is pinned and because every node in this scene is `layout_mode = 0`.

Via MCP, in order:

1. `scene_open("res://Scenes/Lobby/loby.tscn")`
2. `node_manage(op="delete", path="DisplayUang")`
3. `node_create(type="Panel", name="DisplayUang", parent=".")`
4. `node_set_property` on `DisplayUang`:
   - `theme_type_variation` = `"Card"`
   - `layout_mode` = `0`
   - `offset_left` = `700`, `offset_top` = `1392`, `offset_right` = `1032`, `offset_bottom` = `1488`
   - `mouse_filter` = `2`
5. `node_create(type="TextureRect", name="CoinIcon", parent="DisplayUang")`
6. `node_set_property` on `DisplayUang/CoinIcon`:
   - `texture` → `res://Assets/Images/UI/uang.png`
   - `layout_mode` = `0`
   - `offset_left` = `18`, `offset_top` = `20`, `offset_right` = `88`, `offset_bottom` = `76`
   - `expand_mode` = `1`, `stretch_mode` = `5`, `mouse_filter` = `2`
7. `node_create(type="Label", name="Label", parent="DisplayUang")`
8. `node_set_property` on `DisplayUang/Label`:
   - `theme_type_variation` = `"CoinLabel"`
   - `layout_mode` = `0`
   - `offset_left` = `100`, `offset_top` = `18`, `offset_right` = `314`, `offset_bottom` = `78`
   - `text` = `"50"`, `horizontal_alignment` = `2`, `vertical_alignment` = `1`
9. `scene_save()`

- [ ] **Step 4: Repoint the two shop coin icons**

Via MCP:

- `scene_open("res://Scenes/Koperasi/koprasi.tscn")` → `node_set_property("CoinHUD/CoinIcon", "texture", "res://Assets/Images/UI/uang.png")` → `scene_save()`
- `scene_open("res://Scenes/Inventory/inventory.tscn")` → `node_set_property("MainColumn/Header/Row/CoinDisplay/CoinIcon", "texture", "res://Assets/Images/UI/uang.png")` → `scene_save()`

`Assets/Images/Shop/Koin.png` and `Assets/Images/UI/Koin.png` are left in place, not overwritten — they are 33×33, shared, and the aspect change to 1.245:1 could break a layout not surveyed here.

- [ ] **Step 5: Check scene_save did not flush a stale script buffer**

```bash
cd "/c/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project" && git diff HEAD --stat -- '*.gd'
```

Expected: empty.

- [ ] **Step 6: Run the lobby suites**

Via MCP: `test_run(suite="lobby")` and `test_run(suite="lobby_layout")`.

Expected: both PASS. `test_lobby_layout`'s `test_hud_does_not_sit_on_the_front_row_faces` checks `DisplayUang` against head circles at (225, 389) and (845, 389) r=110 — the new rect at y 1392–1488 clears them — and its rim check needs the right edge ≤ 1056, which 1032 satisfies.

- [ ] **Step 7: Delete the resolved debt entry**

In `CLAUDE.md`, delete the whole `**DisplayUang's texture is off-palette.**` paragraph under "Outstanding debt & placeholders". The guide's own rule: *delete an entry when it is resolved — do not mark it done and leave it here.*

- [ ] **Step 8: Screenshot the lobby**

Via MCP: `project_run()`, seed with ⚡ Seed Playtest State, `editor_screenshot()`.

Confirm: the chip is warm rather than pink, coin and number sit side by side, and its bottom edge lines up with the DailyLogin button's.

- [ ] **Step 9: Commit**

```bash
git add Scenes/Lobby/loby.tscn Scenes/Koperasi/koprasi.tscn Scenes/Inventory/inventory.tscn tests/test_lobby.gd CLAUDE.md
git commit -m "feat(lobby): rebuild the money chip and share one coin

DisplayUang was a 1920x1080 pink landscape PNG with a label on top --
off-palette, and the only reason the chip was 332x187 instead of the
332x96 the layout wanted. Now a Panel on the Card variation at 332x96,
bottom-aligned with DailyLogin, holding uang.png and a CoinLabel.

Koperasi and Inventory read the same coin, so money looks like one
currency. Closes the DisplayUang debt entry.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 8: Daily login overhaul

Each `dayN.png` is the **whole panel**: red spiral-bound header with an empty cream title plate, seven reward slots with slot *N* lit gold and carrying a gift icon, and a gold claim pill at bottom-centre. The seven `DayN` overlay nodes become redundant.

Depends on Task 7 — both edit `loby.tscn`, `loby.gd` and `tests/test_lobby.gd`.

**Files:**
- Modify: `Scenes/Lobby/loby.tscn` (the `DailyLogin` block at 411 and the `DailyReward` block at 421–650)
- Modify: `Scripts/Lobby/loby.gd:634-661, 700-720, 755-780`
- Modify: `tests/test_lobby.gd:114-117, 200-210`

**Interfaces:**
- Consumes: `Assets/Images/UI/icon_daily_login.png`, `Assets/Images/UI/DailyLogin/day1.png`…`day7.png`, `Assets/Images/UI/uang.png` from Task 1; `"GhostButton"` from Task 2.
- Produces: `DAY_PANELS: Array[Texture2D]` on `loby.gd` — seven preloaded panels, index 0 = day 1. `day_nodes` and its tinting loop are **removed**.

- [ ] **Step 1: Write the failing tests**

In `tests/test_lobby.gd`, first **delete** the two now-invalid loops.

In `test_scene_instantiates`, remove:

```gdscript
	for i in range(1, 8):
		assert_true(_lobby.get_node_or_null("DailyReward/Day%d" % i) != null,
			"missing Day%d" % i)
```

In `test_labels_use_theme_variations`, remove the trailing `for i in range(1, 8): for sub in ["Label", "Label2"]:` loop and its body.

Then append:

```gdscript
## The panel art carries the whole calendar -- seven slots with the
## active one lit and holding a gift. The seven overlay tiles and their
## "10G"/"DayN" labels are gone with it.
func test_the_day_tiles_are_gone() -> void:
	for i in range(1, 8):
		assert_true(_lobby.get_node_or_null("DailyReward/Day%d" % i) == null,
			"Day%d should be gone -- the panel art shows the day" % i)


func test_the_panel_swaps_art_per_day() -> void:
	var src := FileAccess.get_file_as_string("res://Scripts/Lobby/loby.gd")
	assert_true(src.contains("DAY_PANELS"),
		"the seven panels must be a named const, not seven inline loads")
	for i in range(1, 8):
		assert_true(src.contains("DailyLogin/day%d.png" % i),
			"day %d's panel must be referenced" % i)
	assert_false(src.contains("day_nodes"),
		"the per-tile tint bookkeeping goes with the tiles")


func test_the_lobby_button_wears_the_calendar_icon() -> void:
	var btn := _lobby.get_node_or_null("DailyLogin") as TextureButton
	assert_true(btn != null, "the DailyLogin button is missing")
	assert_eq(btn.texture_normal.resource_path,
		"res://Assets/Images/UI/icon_daily_login.png",
		"it wears the calendar icon")


## Header top-centre, claim button bottom-centre, both on the display
## face -- the panel art bakes a cream title plate and a gold pill for
## exactly these two, so they sit on top of the art rather than beside it.
func test_the_header_and_claim_button_sit_on_the_baked_art() -> void:
	var header := _lobby.get_node_or_null("DailyReward/Label") as Label
	assert_true(header != null, "missing the panel header")
	assert_eq(header.text, "Daily Login", "the header names the feature")
	assert_eq(header.theme_type_variation, &"H1Label",
		"the header is on the display face")

	var panel := _lobby.get_node_or_null("DailyReward") as Control
	var claim := _lobby.get_node_or_null("DailyReward/ButtonClaim") as Button
	assert_true(claim != null, "missing the claim button")
	assert_eq(claim.theme_type_variation, &"GhostButton",
		"the claim button draws nothing -- the baked gold pill is the button")
	var claim_mid: float = claim.offset_left + claim.size.x * 0.5
	assert_true(absf(claim_mid - panel.size.x * 0.5) < 40.0,
		"the claim button is centred, its middle is at %f of %f"
			% [claim_mid, panel.size.x])
	assert_true(claim.offset_top > panel.size.y * 0.6,
		"and sits in the panel's lower third")


func test_the_panel_grew_to_the_arts_aspect() -> void:
	var panel := _lobby.get_node_or_null("DailyReward") as Control
	assert_true(panel != null, "missing the DailyReward panel")
	var aspect: float = panel.size.x / panel.size.y
	assert_true(absf(aspect - 2.253) < 0.05,
		"the panel must match the art's 2.253:1, got %f" % aspect)
```

- [ ] **Step 2: Run the tests to verify they fail**

Via MCP: `test_run(suite="lobby")`.
Expected: FAIL — the `DayN` tiles still exist, `DAY_PANELS` is not in the source, and the header still reads "Daily Reward".

- [ ] **Step 3: Rework the panel in the editor**

Via MCP, in order:

1. `scene_open("res://Scenes/Lobby/loby.tscn")`
2. `node_set_property("DailyLogin", "texture_normal", "res://Assets/Images/UI/icon_daily_login.png")`
3. `node_manage(op="delete", path="DailyReward/Day1")` … through `Day7` — seven deletes; each takes its `Label` and `Label2` children with it.
4. `node_set_property` on `DailyReward`:
   - `texture` → `res://Assets/Images/UI/DailyLogin/day1.png`
   - `offset_left` = `80`, `offset_top` = `558`, `offset_right` = `1022`, `offset_bottom` = `976` (942×418, the art's 2.253:1, top-left anchor unchanged)
5. `node_set_property` on `DailyReward/Label`:
   - `text` = `"Daily Login"`
   - `offset_left` = `330`, `offset_top` = `22`, `offset_right` = `612`, `offset_bottom` = `92`
   - `horizontal_alignment` = `1`
   (variation stays `H1Label` — already the display face)
6. `node_set_property` on `DailyReward/ButtonClaim`:
   - `theme_type_variation` = `"GhostButton"`
   - `offset_left` = `330`, `offset_top` = `318`, `offset_right` = `612`, `offset_bottom` = `396`
   - `text` = `"KLAIM"`
7. `node_create(type="TextureRect", name="RewardCoin", parent="DailyReward")` →
   `texture` → `res://Assets/Images/UI/uang.png`, `layout_mode` = `0`,
   `offset_left` = `640`, `offset_top` = `336`, `offset_right` = `700`, `offset_bottom` = `384`,
   `expand_mode` = `1`, `stretch_mode` = `5`, `mouse_filter` = `2`
8. `node_create(type="Label", name="RewardAmount", parent="DailyReward")` →
   `theme_type_variation` = `"CoinLabel"`, `layout_mode` = `0`,
   `offset_left` = `708`, `offset_top` = `334`, `offset_right` = `828`, `offset_bottom` = `386`,
   `text` = `"10G"`, `vertical_alignment` = `1`
9. `scene_save()`

The exact offsets in steps 5–8 are first estimates against the baked art. Step 8's screenshot is where they get corrected.

- [ ] **Step 4: Check scene_save did not flush a stale script buffer**

```bash
cd "/c/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project" && git diff HEAD --stat -- '*.gd'
```

Expected: empty. Scene work is done; script work starts next.

- [ ] **Step 5: Swap the panel per day and drop the tile bookkeeping**

In `Scripts/Lobby/loby.gd`:

Add the panel table near the top, beside `DAILY_REWARD`:

```gdscript
## The daily-login panel, one frame per streak day. The art bakes all
## seven slots with the active one lit, so the whole calendar is a single
## texture swap -- there are no per-day nodes to tint any more.
const DAY_PANELS: Array[Texture2D] = [
	preload("res://Assets/Images/UI/DailyLogin/day1.png"),
	preload("res://Assets/Images/UI/DailyLogin/day2.png"),
	preload("res://Assets/Images/UI/DailyLogin/day3.png"),
	preload("res://Assets/Images/UI/DailyLogin/day4.png"),
	preload("res://Assets/Images/UI/DailyLogin/day5.png"),
	preload("res://Assets/Images/UI/DailyLogin/day6.png"),
	preload("res://Assets/Images/UI/DailyLogin/day7.png"),
]
```

Replace the body of `_update_daily_login_visual()` (lines 634–661) entirely:

```gdscript
func _update_daily_login_visual() -> void:
	var today := Time.get_date_string_from_system()
	var already_claimed_today: bool = GameState.last_claim_date == today

	if daily_reward:
		var day := clampi(GameState.daily_login_day, 1, DAY_PANELS.size())
		daily_reward.texture = DAY_PANELS[day - 1]

	if claim_button and claim_button is BaseButton:
		claim_button.disabled = already_claimed_today
```

Delete the `day_nodes` declaration and every remaining reference to it. In `_show_daily_reward()` (around line 700), delete the `ordered_days` block and the `Juice.stagger_in(ordered_days)` call — the panel's own `Juice.pop_in(daily_reward)` stays.

In `_on_claim_pressed()` (around line 770), replace the claimed-tile pop:

```gdscript
	# The tiles are gone -- the panel itself is what pops now.
	if daily_reward:
		Juice.pop_in(daily_reward)
```

and delete the now-unused `var claimed_day := GameState.daily_login_day` line above it.

- [ ] **Step 6: Rescan and run the lobby suites**

Via MCP: `filesystem_manage(op="scan")`, then `test_run(suite="lobby")` and `test_run(suite="lobby_layout")`.
Expected: both PASS.

If the source-text tests still see `day_nodes`, force a script reload with a no-op `script_patch` on `loby.gd`.

- [ ] **Step 7: Run the whole suite**

Via MCP: `test_run()`.
Expected: all green.

- [ ] **Step 8: Screenshot and correct the offsets**

Via MCP: `project_run()`, seed with ⚡ Seed Playtest State, tap the daily-login button, `editor_screenshot()`.

Confirm and correct: "Daily Login" sits inside the baked cream plate; "KLAIM" sits on the baked gold pill and does not overhang it; the coin and "10G" clear the pill. Repeat step 3's `node_set_property` calls with corrected offsets until they line up, then `scene_save()` and re-run the suite.

- [ ] **Step 9: Commit**

```bash
git add Scenes/Lobby/loby.tscn Scripts/Lobby/loby.gd tests/test_lobby.gd
git commit -m "feat(lobby): rebuild daily login on the new panel art

Each dayN.png is the whole calendar with slot N lit, so the seven overlay
tiles, their 10G/DayN labels and the per-tile tint loop are all gone --
the day is a single texture swap. The lobby button wears the calendar
icon, the header reads Daily Login on the baked cream plate, and the
claim button is a GhostButton over the baked gold pill.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 9: RunResult — five ranks and the win backdrop

Two changes to the same screen, committed separately: the rank scheme collapses from ten `+`/`−` bands to five badges, and the win backdrop is repointed to the image `RunResult.gd`'s own docstring already claims it shows.

**Files:**
- Modify: `Scripts/EndGame/RunGrade.gd:23-30, 58-68`
- Modify: `Scripts/EndGame/RunResult.gd:45, 62-77, 89, 179-205`
- Modify: `Scenes/EndGame/RunResult.tscn:4, 29, 70-75`
- Modify: `tests/test_run_result.gd`
- Modify: `CLAUDE.md` (extend the pending-balance-pass entry)

**Interfaces:**
- Consumes: `Assets/Images/EndGame/Ranks/rank_s.png` … `rank_d.png` from Task 1.
- Produces:
  - `RunGrade.LETTER_BANDS` = `[[90.0,"S"],[75.0,"A"],[60.0,"B"],[45.0,"C"]]`; `RunGrade.LETTER_FLOOR` = `"D"`; `RunGrade.LETTER_FAILED` = `"D"`.
  - `RunGrade.letter(run_score: float, passed: bool) -> String` — signature unchanged, now returns one of `S`/`A`/`B`/`C`/`D`.
  - `RunGrade.is_top_grade(letter_text: String) -> bool` — true for `S` and `A` only.
  - `RunResult` gains five `@export var rank_badge_s|a|b|c|d: Texture2D`, and `$MarginContainer/Column/GradeCard/GradeStack/GradeBadge` replaces `GradeLetter`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_run_grade_ranks.gd`. It uses `assert_not_null`, so it **must** `extends McpTestSuiteCompat`.

```gdscript
@tool
extends McpTestSuiteCompat

## The run's letter grade, collapsed from ten +/- bands to five ranks
## with badge art -- S at the top, D always on a failed run.
##
## Must be @tool; no test here may be a coroutine.

func suite_name() -> String:
	return "run_grade_ranks"


const SCRIPT_PATH := "res://Scripts/EndGame/RunGrade.gd"
const RESULT_SCRIPT := "res://Scripts/EndGame/RunResult.gd"
const SCENE_PATH := "res://Scenes/EndGame/RunResult.tscn"


func test_there_are_exactly_five_ranks() -> void:
	var seen := {}
	for s in [100.0, 92.0, 90.0, 80.0, 75.0, 62.0, 60.0, 50.0, 45.0, 20.0, 0.0]:
		seen[RunGrade.letter(s, true)] = true
	var ranks: Array = seen.keys()
	ranks.sort()
	assert_eq(ranks.size(), 5, "five ranks, got %s" % str(ranks))
	for r in ["S", "A", "B", "C", "D"]:
		assert_true(seen.has(r), "rank %s must be reachable" % r)


func test_the_bands_sit_where_the_spec_put_them() -> void:
	assert_eq(RunGrade.letter(90.0, true), "S", "90 is the S floor")
	assert_eq(RunGrade.letter(89.9, true), "A", "just under it is an A")
	assert_eq(RunGrade.letter(75.0, true), "A", "75 is the A floor")
	assert_eq(RunGrade.letter(74.9, true), "B", "just under it is a B")
	assert_eq(RunGrade.letter(60.0, true), "B", "60 is the B floor")
	assert_eq(RunGrade.letter(59.9, true), "C", "just under it is a C")
	assert_eq(RunGrade.letter(45.0, true), "C", "45 is the C floor")
	assert_eq(RunGrade.letter(44.9, true), "D", "below that is a D")


## Unchanged rule, restated because it is the one the player feels: the
## letter rewards winning well, it is not a consolation for losing.
func test_a_failed_run_is_always_d_however_well_it_scored() -> void:
	assert_eq(RunGrade.letter(100.0, false), "D",
		"a perfect score on a failed run is still a D")


func test_the_plus_minus_bands_are_gone() -> void:
	var src := FileAccess.get_file_as_string(SCRIPT_PATH)
	for retired in ["\"A+\"", "\"A-\"", "\"B+\"", "\"B-\"", "\"C+\"", "\"C-\""]:
		assert_false(src.contains(retired),
			"%s is superseded by the five-rank scheme" % retired)


func test_s_and_a_are_the_top_grades() -> void:
	assert_true(RunGrade.is_top_grade("S"), "S is a top grade")
	assert_true(RunGrade.is_top_grade("A"), "so is A")
	assert_false(RunGrade.is_top_grade("B"), "B is not")
	assert_false(RunGrade.is_top_grade("D"), "and D certainly is not")


func test_every_rank_has_a_caption() -> void:
	var src := FileAccess.get_file_as_string(RESULT_SCRIPT)
	var from := src.find("const GRADE_CAPTIONS")
	var to := src.find("}", from)
	var body := src.substr(from, to - from)
	for r in ["S", "A", "B", "C", "D"]:
		assert_true(body.contains("\"%s\":" % r),
			"rank %s needs a caption" % r)


## The badge art draws the letter and a RANK ribbon itself, so a text
## label beside it would just repeat it.
func test_the_grade_is_a_badge_not_a_letter_label() -> void:
	var screen = load(SCENE_PATH).instantiate()
	var stack := "MarginContainer/Column/GradeCard/GradeStack"
	var badge = screen.get_node_or_null("%s/GradeBadge" % stack)
	var old_label = screen.get_node_or_null("%s/GradeLetter" % stack)
	screen.free()
	assert_not_null(badge, "GradeBadge must exist")
	assert_true(badge is TextureRect, "and be a TextureRect, never a Label")
	assert_true(old_label == null,
		"GradeLetter is retired -- the badge draws its own letter")


func test_all_five_badges_are_inspector_assignable() -> void:
	var screen = load(SCENE_PATH).instantiate()
	var missing: Array[String] = []
	for r in ["s", "a", "b", "c", "d"]:
		if screen.get("rank_badge_%s" % r) == null:
			missing.append(r)
	screen.free()
	assert_eq(missing.size(), 0,
		"every rank badge must be assigned in the Inspector, missing: %s"
			% str(missing))
```

Then, in `tests/test_run_result.gd`, update `test_the_screen_has_a_backdrop_grade_card_and_rows_box` — change the `GradeLetter` path to `GradeBadge`:

```gdscript
		and screen.get_node_or_null(
			"MarginContainer/Column/GradeCard/GradeStack/GradeBadge") != null \
```

And append the backdrop guard:

```gdscript
## RunResult.gd's own docstring has always promised "the SAME image
## EndCutscene shows". It pointed at cg_win.jpg while EndCutscene's win
## branch moved to win_background.png, so the hand-off was a visible cut.
func test_the_win_backdrop_is_the_image_the_cutscene_actually_ends_on() -> void:
	var run_src := FileAccess.get_file_as_string(_SCENE_PATH)
	var cut_src := FileAccess.get_file_as_string(
		"res://Scenes/EndGame/EndCutscene.tscn")
	var want := "Assets/Images/CG/Win/win_background.png"
	assert_true(cut_src.contains(want),
		"EndCutscene's win branch shows the win background")
	assert_true(run_src.contains(want),
		"and RunResult must open on that same image, not cg_win.jpg")
	assert_false(run_src.contains("cg_win.jpg"),
		"the old, smaller win CG must no longer be referenced")
```

- [ ] **Step 2: Run the tests to verify they fail**

Via MCP: `filesystem_manage(op="scan")`, then `test_run(suite="run_grade_ranks")` and `test_run(suite="run_result")`.
Expected: FAIL — `letter()` still returns `A+`/`B-`/etc, `GradeBadge` does not exist, and `RunResult.tscn` still references `cg_win.jpg`.

- [ ] **Step 3: Collapse the bands in RunGrade**

In `Scripts/EndGame/RunGrade.gd`, replace the band block:

```gdscript
## Score floors for each rank, highest first. Read top-down.
##
## Five ranks, one per badge, since 2026-09-10 -- ten +/- bands could not
## be told apart on a badge that draws its own letter. Like
## MONEY_FULL_MARKS above, these floors are estimates awaiting the balance
## pass, not tuned numbers.
const LETTER_BANDS := [
	[90.0, "S"], [75.0, "A"], [60.0, "B"], [45.0, "C"],
]
const LETTER_FLOOR := "D"
const LETTER_FAILED := "D"
```

And widen the top-grade test:

```gdscript
## S and A both light the success colour and the reward sting.
static func is_top_grade(letter_text: String) -> bool:
	return letter_text == "S" or letter_text == "A"
```

Then update the class docstring at the top of the file: change line 4's `## Turns a finished run into a 0-100 score and a letter grade.` to `## Turns a finished run into a 0-100 score and one of five ranks.` Line 10's `A failed run is always "D"` stays — it is still exactly true.

- [ ] **Step 4: Rewrite the captions and swap the label for a badge**

In `Scripts/EndGame/RunResult.gd`, replace `GRADE_CAPTIONS`:

```gdscript
## One caption per rank, so the grade says something rather than just
## scoring something.
const GRADE_CAPTIONS := {
	"S": "Sempurna. Tidak ada yang tertinggal.",
	"A": "Luar biasa. Kelas ini beruntung punya kamu.",
	"B": "Baik. Targetnya tercapai.",
	"C": "Lulus tipis. Lain kali lebih awal.",
	"D": "Belum berhasil. Mereka masih menunggumu.",
}
```

Add the five badge exports next to the existing `@export_group("Backdrop")` block:

```gdscript
@export_group("Rank badges")
## Shown for an S rank. The art draws its own letter and RANK ribbon, so
## there is no text label beside it.
@export var rank_badge_s: Texture2D
## Shown for an A rank.
@export var rank_badge_a: Texture2D
## Shown for a B rank.
@export var rank_badge_b: Texture2D
## Shown for a C rank.
@export var rank_badge_c: Texture2D
## Shown for a D rank, which is also every failed run.
@export var rank_badge_d: Texture2D
```

Replace the `grade_letter` binding at line 45:

```gdscript
@onready var grade_badge: TextureRect = $MarginContainer/Column/GradeCard/GradeStack/GradeBadge
```

In `_ready()`, replace `grade_letter.text = ""` with:

```gdscript
	grade_badge.texture = null
```

Add the lookup helper and rewrite `_slam_grade()`:

```gdscript
## The badge for a rank. Falls back to D, which is also the failed-run
## rank, so an unmapped string can never leave the card empty.
func _badge_for(rank: String) -> Texture2D:
	match rank:
		"S": return rank_badge_s
		"A": return rank_badge_a
		"B": return rank_badge_b
		"C": return rank_badge_c
		_: return rank_badge_d


func _slam_grade() -> void:
	grade_badge.texture = _badge_for(_grade_text)
	grade_caption.text = String(GRADE_CAPTIONS.get(_grade_text, ""))

	Juice.set_pivot_center(grade_badge)
	grade_badge.scale = Vector2(3.0, 3.0)
	grade_badge.modulate.a = 0.0

	var t := Juice.tokens()
	var tw := grade_badge.create_tween().set_parallel(true)
	tw.tween_property(grade_badge, "scale", Vector2.ONE, t.dur_fast) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tw.tween_property(grade_badge, "modulate:a", 1.0, t.dur_instant)
	tw.chain().tween_callback(func() -> void:
		AudioDirector.play_sfx(&"stamp")
		Juice.shake(grade_badge.get_parent(), 8.0)
		if RunGrade.is_top_grade(_grade_text):
			AudioDirector.play_sfx(&"reward")
		elif _grade_text == "D":
			AudioDirector.play_sfx(&"fail"))
```

The `add_theme_color_override("font_color", ...)` from the old body is deleted outright — it has no meaning on a texture, and it was a `theme_override` the style rules forbid anyway.

- [ ] **Step 5: Swap the node and assign the badges in the editor**

Via MCP, in order:

1. `scene_open("res://Scenes/EndGame/RunResult.tscn")`
2. `node_manage(op="delete", path="MarginContainer/Column/GradeCard/GradeStack/GradeLetter")`
3. `node_create(type="TextureRect", name="GradeBadge", parent="MarginContainer/Column/GradeCard/GradeStack")`
4. `node_set_property` on `GradeBadge`:
   - `custom_minimum_size` = `Vector2(300, 290)`
   - `expand_mode` = `1`, `stretch_mode` = `5`
   - `size_flags_horizontal` = `4` (shrink-centre)
   - `mouse_filter` = `2`
5. `node_manage(op="move", path=".../GradeStack/GradeBadge", to_index=0)` — the badge sits above `GradeCaption`.
6. `node_set_property` on the root `RunResult`, five properties: `rank_badge_s` … `rank_badge_d` → the five `res://Assets/Images/EndGame/Ranks/rank_*.png`.
7. `scene_save()`

- [ ] **Step 6: Check scene_save did not flush a stale script buffer**

```bash
cd "/c/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project" && git diff HEAD --stat -- '*.gd'
```

Expected: only `RunGrade.gd` and `RunResult.gd`, which you edited.

- [ ] **Step 7: Rescan and run the tests**

Via MCP: `filesystem_manage(op="scan")`, then `test_run(suite="run_grade_ranks")` and `test_run(suite="run_result")`.
Expected: the rank tests PASS; the backdrop test still FAILS (that is step 9).

- [ ] **Step 8: Commit the rank change**

```bash
git add Scripts/EndGame/RunGrade.gd Scripts/EndGame/RunResult.gd Scenes/EndGame/RunResult.tscn tests/test_run_grade_ranks.gd tests/test_run_result.gd
git commit -m "feat(endgame): collapse the run grade to five ranks with badges

Ten +/- bands could not be told apart on a badge that draws its own
letter. Now S/A/B/C/D at 90/75/60/45, with D still forced on any failed
run, and the GradeLetter label replaced by a GradeBadge TextureRect fed
by five Inspector-assigned textures. The slam-in moves to the badge.

Thresholds are estimates awaiting the balance pass, like MONEY_FULL_MARKS.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

- [ ] **Step 9: Repoint the win backdrop**

Via MCP:

1. `scene_open("res://Scenes/EndGame/RunResult.tscn")`
2. `node_set_property(".", "win_backdrop", "res://Assets/Images/CG/Win/win_background.png")`
3. `node_set_property("Backdrop", "texture", "res://Assets/Images/CG/Win/win_background.png")`
4. `scene_save()`

`expand_mode = 1`, `stretch_mode = 6`, `blur_lod = 3.0` and `blur_darkness = 0.3` already match EndCutscene on both sides, so nothing else moves. The lose path keeps `cg_lose.jpg`, which still matches.

- [ ] **Step 10: Run the whole suite**

Via MCP: `test_run()`.
Expected: all green, including `test_both_screens_dim_the_blur_by_the_same_amount` and `test_the_backdrop_is_dressed_from_the_same_verdict_flag`, which this must not disturb.

- [ ] **Step 11: Screenshot the win hand-off**

Via MCP: `project_run()`, then the debug overlay's Scenes tab → 🎭 Gladi Resik Akhir Kelas → *Semua Lulus*. Arming it snapshots the run first. Screenshot the last EndCutscene frame and the first RunResult frame.

Confirm: the two frames show the same image at the same blur and dim — no visible cut — and the badge slams in over it. Afterwards use ↩ Pulihkan Run Sebelum Gladi Resik, because RunResult's progression otherwise advances the grade and clears the roster on its way out.

- [ ] **Step 12: Record the estimated thresholds as debt**

In `CLAUDE.md`, extend the existing `**Pending a balance pass.**` entry — append to it:

```markdown
`RunGrade.LETTER_BANDS`' five rank floors (S 90 / A 75 / B 60 / C 45) are
estimates set when the scheme collapsed from ten +/- bands on 2026-09-10,
never played against a real run.
```

- [ ] **Step 13: Commit**

```bash
git add Scenes/EndGame/RunResult.tscn tests/test_run_result.gd CLAUDE.md
git commit -m "fix(endgame): open RunResult on the CG the cutscene ended on

RunResult.gd has always documented its win backdrop as 'the SAME image
EndCutscene shows', but pointed at cg_win.jpg (735x865) while
EndCutscene's win branch had moved to win_background.png (1536x2048), so
the hand-off was a visible cut. Blur lod, darkness and stretch already
matched; only the texture was wrong.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Final verification

- [ ] **Full suite green**

Via MCP: `filesystem_manage(op="scan")`, then `test_run()` with `Scenes/MainMenu/main_menu.tscn` open in the editor.
Expected: zero `failed`, and — importantly — zero `load_errors`. A suite that fails to instantiate does not move the failure count off zero, which is exactly the hole `test_every_non_null_assertion_caller_extends_the_compat_shim` exists to close.

- [ ] **No stray script damage across the whole branch**

```bash
cd "/c/Users/user/Downloads/KejarTestAlphaVer2.15/KejarTestAlphaVer2.15/new-game-project" && git status --short && git diff origin/Textures --stat
```

Expected: nothing unexpected — in particular no untracked or modified `Assets/Theme/kejartes_theme.tres` beyond the two-variation bake, and no touched `default_bus_layout.tres`.

- [ ] **Changelog entry**

Add one entry to `docs/superpowers/CHANGELOG.md`, newest first, covering all six changes and naming every placeholder each one leaves behind — including the uncleaned corner artifact in the new sky source. Commit as `docs(changelog): record the 2026-09-10 asset refresh and UI pass`.
