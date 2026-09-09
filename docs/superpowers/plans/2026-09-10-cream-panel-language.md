# Cream Panel Language Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace AturJadwal's four-surface olive activity rows with a single cream sheet carrying inset tracks, give the two gauge-less rows a ghosted track, add a press-inset, and split the green/red confirm pair by meaning.

**Architecture:** Everything visual flows from `Assets/Theme/design_tokens.tres` through `ThemeFactory.build()` into the baked `Assets/Theme/kejartes_theme.tres`. Tasks 1–2 change tokens and the styleboxes built from them. Tasks 3–6 change the one scene that consumes those variations. Task 7 is an independent semantic pass over button variations in other scenes. No task adds runtime visual construction; repeated visuals are scene nodes.

**Tech Stack:** Godot 4.6 (mobile renderer, Vulkan), GDScript, `McpTestSuite` via the Godot AI MCP `test_run` tool, PowerShell + `System.Drawing` for placeholder PNG generation.

**Spec:** `docs/superpowers/specs/2026-09-10-cream-panel-language-design.md`

## Global Constraints

- **Never add a `theme_override_*`.** Use a `ThemeFactory` type variation. Only accepted exception: layout-only constant overrides (`separation`, `margin_*`).
- **No visual is built at runtime.** Static chrome is a node in the `.tscn`; repeated rows are a `PackedScene`; responsive geometry is a `@tool` script with documented `@export` knobs.
- **Every test suite must be `@tool`** and extend `McpTestSuite`, or the runner reports it abstract.
- **No test may be a coroutine.** The runner calls `suite.call(name)` without awaiting; an `await` silently aborts the test and it reports "0 assertions".
- **Every script needs a `##` file header and a `##` line on every `@export`** — enforced by `tests/test_script_documentation.gd`.
- **No emoji as UI iconography.** Use transparent SVG/PNG textures.
- **Never hand-edit a `.tscn` while the editor is attached.** Go through `scene_open` → `node_create` / `node_set_property` → `scene_save`.
- **Do scene work first, script work second.** `scene_save` flushes stale script buffers over patched `.gd` files. After any `scene_save`, check `git diff HEAD -- '*.gd'` for files you were not editing.
- **Rescan after editing a `.gd`, before running tests**, or `test_run` serves a stale autoload. If the `.gd` was edited from outside the editor, force the reload with a no-op `script_patch` on that file.
- **Overrides serialise only on an instanced scene's ROOT.** Properties set on an instance's children report success and are dropped on save.
- **`Balance.gd` is owned by a collaborator.** Read freely; never edit.
- **Game-facing identifiers and UI text are Indonesian**; engine and systems code is English.
- Commits use Conventional Commits with a scope, e.g. `fix(lobby): wire the dead ReportStudent button`.
- The suite is 960 tests across 65 suites and must stay green.

## File Structure

**Modified:**
- `Assets/Theme/design_tokens.tres` — two recoloured tokens, two new ones.
- `Scripts/Design/DesignTokens.gd` — two new `@export`s with `##` docs.
- `Scripts/Design/ThemeFactory.gd` — `PreviewRow` recolour; new `PreviewRowPressed`, `PreviewRowSeparator`, `PreviewTrackGhost`.
- `Scenes/AturJadwal/ActivityRow.tscn` — separator node, ghost-track wiring, watermark `TextureRect`.
- `Scripts/AturJadwal/ActivityRow.gd` — press-state swap, ghost-track branch, watermark `@export`s.
- `Assets/Images/UI/penjadwalan_card_bg.png` — replaced in place with a cream recolour.
- Task 7's scenes and scripts, listed in that task.

**Created:**
- `Assets/Images/UI/BarFill/track_ghost.png`
- `Assets/Images/UI/BarFill/icon_ghost_koin.png`
- `Assets/Images/UI/BarFill/icon_ghost_sabit.png`
- `tests/test_cream_panel_tokens.gd`
- `tests/test_ghost_track.gd`
- `tests/test_confirm_pair_semantics.gd`

**Read but not modified:** `tests/test_bar_contrast.gd`, `tests/test_viewport_editability.gd`, `Scripts/Design/BakeTheme.gd`.

## How to rebake the theme

Several tasks require a rebake. `BakeTheme.gd` is an `EditorScript` with no MCP entry point, so use one of these:

**By hand:** open `Scripts/Design/BakeTheme.gd` in the editor, File > Run (Ctrl+Shift+X).

**Headlessly:** write a transient `@tool` suite into `res://tests/`, run it with `test_run`, then delete it:

```gdscript
@tool
extends McpTestSuite

## Transient: drives the theme rebake, which has no MCP entry point.
## Delete after running.

func suite_name() -> String:
	return "transient_rebake"


func test_rebake() -> void:
	var tokens := DesignTokens.load_default()
	assert_not_null(tokens, "design_tokens.tres failed to load")
	var theme := ThemeFactory.build(tokens)
	var err := ResourceSaver.save(theme, "res://Assets/Theme/kejartes_theme.tres")
	assert_eq(err, OK, "theme save failed with error %d" % err)
```

---

### Task 1: New tokens for the cream row

A new `@export` on a `Resource` is invisible to a running editor. This task therefore ends with an editor restart, and Task 2 cannot start until it has happened.

**Files:**
- Modify: `Scripts/Design/DesignTokens.gd:277-295` (the preview token block)
- Modify: `Assets/Theme/design_tokens.tres`
- Test: `tests/test_cream_panel_tokens.gd` (create)

**Interfaces:**
- Consumes: nothing.
- Produces: `DesignTokens.preview_row_fill: Color`, `preview_pill_fill: Color`, `preview_row_separator: Color`, `preview_row_pressed_fill: Color`. Task 2 reads all four.

- [ ] **Step 1: Write the failing test**

Create `tests/test_cream_panel_tokens.gd`:

```gdscript
@tool
extends McpTestSuite

## The four tokens behind AturJadwal's cream activity row.
##
## Before this pass a row nested four surfaces: the olive card, a
## #6B4B33 slab, a #4A3728 inset pill, and the category bar. The mentor
## review on 2026-09-08 called that cluttered. These tokens collapse it
## to a cream sheet with one recessed track.

const CREAM_SHEET := Color("FFFDF8")
const TRACK := Color("E6DAC6")
const SEPARATOR := Color("EFE0CB")
const PRESSED := Color("F0E2CD")


func suite_name() -> String:
	return "cream_panel_tokens"


func test_row_and_track_are_cream() -> void:
	var tokens := DesignTokens.load_default()
	assert_not_null(tokens, "design_tokens.tres failed to load")
	assert_eq(tokens.preview_row_fill, CREAM_SHEET,
		"preview_row_fill should be the cream sheet, not the old brown slab")
	assert_eq(tokens.preview_pill_fill, TRACK,
		"preview_pill_fill should be the light recessed track")


func test_the_two_new_tokens_exist_and_are_set() -> void:
	var tokens := DesignTokens.load_default()
	assert_not_null(tokens, "design_tokens.tres failed to load")
	assert_eq(tokens.preview_row_separator, SEPARATOR,
		"preview_row_separator missing or wrong")
	assert_eq(tokens.preview_row_pressed_fill, PRESSED,
		"preview_row_pressed_fill missing or wrong")


## The press recess must be darker than the resting sheet or the row
## appears to rise on touch instead of sinking.
func test_pressed_fill_is_darker_than_the_resting_sheet() -> void:
	var tokens := DesignTokens.load_default()
	assert_not_null(tokens, "design_tokens.tres failed to load")
	var resting: float = tokens.preview_row_fill.get_luminance()
	var pressed: float = tokens.preview_row_pressed_fill.get_luminance()
	assert_true(pressed < resting,
		"pressed fill (%f) must be darker than resting (%f)" % [pressed, resting])
```

- [ ] **Step 2: Run the test and verify it fails**

Run `test_run` with suite `cream_panel_tokens`.
Expected: FAIL — `preview_row_fill` is still `#6B4B33`, and `preview_row_separator` does not exist.

- [ ] **Step 3: Add the two new `@export`s**

In `Scripts/Design/DesignTokens.gd`, after the `preview_pill_fill` declaration:

```gdscript
## Hairline between activity rows on the cream sheet. Replaces the 3px
## border every row used to carry -- one rule between rows reads as a
## list, four strokes per row read as clutter.
@export var preview_row_separator: Color = Color("EFE0CB")

## The row's fill while held. Darker than preview_row_fill so the row
## sinks on touch; Panel has no pressed state, so ActivityRow.gd swaps
## the stylebox on button_down/button_up.
@export var preview_row_pressed_fill: Color = Color("F0E2CD")
```

- [ ] **Step 4: Recolour the two existing tokens**

Change the defaults in `Scripts/Design/DesignTokens.gd`:

```gdscript
@export var preview_row_fill: Color = Color("FFFDF8")
@export var preview_pill_fill: Color = Color("E6DAC6")
```

Update the `##` doc line above `preview_pill_fill` — it currently says the pill is darker than `preview_row_fill` so it reads as recessed. It is now lighter-warm against a cream sheet. Replace with:

```gdscript
## The recessed track inset into the row, carrying the bar or the
## preview numbers. Warmer and slightly darker than preview_row_fill so
## it reads as a channel cut into the cream sheet.
```

If `design_tokens.tres` carries explicit stored values for either token, update them there too. If it does not (it currently stores only `font_display` and `font_body`, inheriting the rest), the script defaults are the live values and no `.tres` edit is needed.

- [ ] **Step 5: Restart the Godot editor**

Required — the two new `@export`s are invisible to the running editor. Also reclaims the memory this build leaks. After restart, open `Scenes/MainMenu/main_menu.tscn`, since some suites assume the main scene is open.

- [ ] **Step 6: Run the test and verify it passes**

Run `test_run` with suite `cream_panel_tokens`.
Expected: PASS, 3 tests.

- [ ] **Step 7: Run the full suite**

Run `test_run` with no suite filter.
Expected: all green. `test_script_documentation` in particular must pass — both new `@export`s have `##` lines.

- [ ] **Step 8: Commit**

```bash
git add Scripts/Design/DesignTokens.gd Assets/Theme/design_tokens.tres tests/test_cream_panel_tokens.gd
git commit -m "feat(theme): recolour the preview row tokens to cream

The mentor review called the nested olive/brown/dark-brown row stack
cluttered. preview_row_fill becomes the cream sheet and
preview_pill_fill becomes a light recessed track, plus two new tokens
for the hairline separator and the press recess.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: Bake the cream row styleboxes

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd:860-895` (the `preview_row` / `preview_pill` block)
- Modify: `Assets/Theme/kejartes_theme.tres` (regenerated, not hand-edited)
- Test: `tests/test_cream_panel_tokens.gd` (extend)

**Interfaces:**
- Consumes: the four tokens from Task 1.
- Produces: theme type variations `PreviewRow`, `PreviewRowPressed`, `PreviewRowSeparator`. Tasks 3 and 6 consume them by name.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_cream_panel_tokens.gd`:

```gdscript
func test_preview_row_is_cream_and_unstroked() -> void:
	var tokens := DesignTokens.load_default()
	assert_not_null(tokens, "design_tokens.tres failed to load")
	var theme := ThemeFactory.build(tokens)
	var box := theme.get_stylebox("panel", "PreviewRow") as StyleBoxFlat
	assert_not_null(box, "PreviewRow should be a StyleBoxFlat")
	assert_eq(box.bg_color, CREAM_SHEET, "PreviewRow should be cream")
	assert_eq(box.border_width_top, 0, "the 3px stroke should be gone")
	assert_eq(box.border_width_bottom, 0, "the 3px stroke should be gone")
	assert_eq(box.shadow_size, 0, "the hard drop shadow should be gone")


func test_pressed_variation_exists_and_differs_from_resting() -> void:
	var tokens := DesignTokens.load_default()
	assert_not_null(tokens, "design_tokens.tres failed to load")
	var theme := ThemeFactory.build(tokens)
	var resting := theme.get_stylebox("panel", "PreviewRow") as StyleBoxFlat
	var pressed := theme.get_stylebox("panel", "PreviewRowPressed") as StyleBoxFlat
	assert_not_null(pressed, "PreviewRowPressed variation missing")
	assert_ne(pressed.bg_color, resting.bg_color,
		"pressed and resting must not be the same colour")
	assert_eq(pressed.bg_color, PRESSED, "pressed should use the recess token")


func test_separator_variation_is_the_hairline() -> void:
	var tokens := DesignTokens.load_default()
	assert_not_null(tokens, "design_tokens.tres failed to load")
	var theme := ThemeFactory.build(tokens)
	var box := theme.get_stylebox("separator", "PreviewRowSeparator") as StyleBoxLine
	assert_not_null(box, "PreviewRowSeparator should be a StyleBoxLine")
	assert_eq(box.color, SEPARATOR, "separator should use the hairline token")
	assert_eq(box.thickness, 1, "separator should be 1px")
```

- [ ] **Step 2: Run the test and verify it fails**

Run `test_run` with suite `cream_panel_tokens`.
Expected: FAIL — `PreviewRow` still has `border_width_top == 3`, and `PreviewRowPressed` does not exist.

- [ ] **Step 3: Rewrite the `preview_row` block**

In `Scripts/Design/ThemeFactory.gd`, replace the existing `preview_row` construction and its comment:

```gdscript
	# -- Penjadwalan row: a plain cream slab on the sheet. Before the
	# 2026-09-10 pass this was a brown slab with a 3px black stroke and a
	# hard drop shadow; four nested surfaces per row read as clutter. The
	# depth now comes from the inset track alone. --
	var preview_row := StyleBoxFlat.new()
	preview_row.bg_color = tokens.preview_row_fill
	preview_row.set_border_width_all(0)
	preview_row.set_corner_radius_all(tokens.radius_md)
	theme.add_type("PreviewRow")
	theme.set_type_variation("PreviewRow", "Panel")
	theme.set_stylebox("panel", "PreviewRow", preview_row)

	# -- The same slab while held. Panel has no pressed state, so
	# ActivityRow.gd swaps this in on button_down. The inset top edge is
	# what sells the sink; a flat colour change alone reads as a hover. --
	var preview_row_pressed := StyleBoxFlat.new()
	preview_row_pressed.bg_color = tokens.preview_row_pressed_fill
	preview_row_pressed.set_border_width_all(0)
	preview_row_pressed.border_width_top = 2
	preview_row_pressed.border_color = tokens.preview_row_pressed_fill.darkened(0.12)
	preview_row_pressed.set_corner_radius_all(tokens.radius_md)
	theme.add_type("PreviewRowPressed")
	theme.set_type_variation("PreviewRowPressed", "Panel")
	theme.set_stylebox("panel", "PreviewRowPressed", preview_row_pressed)

	# -- The hairline between rows, replacing the per-row stroke. --
	var preview_separator := StyleBoxLine.new()
	preview_separator.color = tokens.preview_row_separator
	preview_separator.thickness = 1
	theme.add_type("PreviewRowSeparator")
	theme.set_type_variation("PreviewRowSeparator", "HSeparator")
	theme.set_stylebox("separator", "PreviewRowSeparator", preview_separator)
```

Leave the `preview_pill` block's construction alone — it already reads `tokens.preview_pill_fill`, which Task 1 recoloured. Its `shadow_color`/`shadow_size` should stay: a soft halo still reads as a recess on cream.

- [ ] **Step 4: Rebake the theme**

Use either method from "How to rebake the theme" above.

- [ ] **Step 5: Run the test and verify it passes**

Run `test_run` with suite `cream_panel_tokens`.
Expected: PASS, 6 tests.

- [ ] **Step 6: Run the full suite**

Run `test_run` with no suite filter. Expected: all green.

`tests/test_theme_factory.gd`'s `DISPLAY_ROSTER` pins which variations use `font_display`. The three new variations set no font, so the roster should not need changing. If that suite fails, add the new variations to the roster's non-display side rather than giving them a font.

- [ ] **Step 7: Commit**

```bash
git add Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres tests/test_cream_panel_tokens.gd
git commit -m "feat(theme): bake the cream preview row, its press state and separator

PreviewRow loses its 3px stroke and hard shadow and becomes a plain
cream slab. Adds PreviewRowPressed for the touch sink and
PreviewRowSeparator for the hairline that replaces the per-row stroke.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Recolour the card background texture

`Assets/Images/UI/penjadwalan_card_bg.png` is the olive slab, used twice in `atur_jadwal.tscn` — once as the row card, once 9-sliced at a different `region_rect` as the "PERINGATAN" dialog panel. Replacing the file in place fixes both without touching either call site.

**Files:**
- Modify: `Assets/Images/UI/penjadwalan_card_bg.png` (replaced in place)
- Modify: `CLAUDE.md` (record the placeholder)

**Interfaces:**
- Consumes: nothing.
- Produces: nothing code-facing.

- [ ] **Step 1: Record the original dimensions**

```bash
cd "C:/Users/Legion/Documents/KEJARTES/new-game-project"
powershell -c "Add-Type -AssemblyName System.Drawing; \$i=[System.Drawing.Image]::FromFile((Resolve-Path 'Assets/Images/UI/penjadwalan_card_bg.png')); '{0}x{1}' -f \$i.Width,\$i.Height; \$i.Dispose()"
```

Note the output. The replacement must match it exactly — `atur_jadwal.tscn` addresses this image with two hardcoded `region_rect` values (`Rect2(211, 34, 658, 1013)` for the dialog) and any size change breaks both.

- [ ] **Step 2: Back up the original**

```bash
cp Assets/Images/UI/penjadwalan_card_bg.png "$TMPDIR/penjadwalan_card_bg.olive.png" 2>/dev/null || cp Assets/Images/UI/penjadwalan_card_bg.png /tmp/penjadwalan_card_bg.olive.png
```

- [ ] **Step 3: Generate the cream recolour**

Write and run a PowerShell script that reads the original, maps every pixel's hue to the cream family while preserving its alpha and relative luminance, and writes back to the same path at the same dimensions. Keep the existing rim: the card reads as a card because of its darker edge.

```powershell
Add-Type -AssemblyName System.Drawing
$src = [System.Drawing.Bitmap]::FromFile((Resolve-Path 'Assets/Images/UI/penjadwalan_card_bg.png'))
$out = New-Object System.Drawing.Bitmap $src.Width, $src.Height
for ($y = 0; $y -lt $src.Height; $y++) {
  for ($x = 0; $x -lt $src.Width; $x++) {
    $p = $src.GetPixel($x, $y)
    $lum = (0.299 * $p.R + 0.587 * $p.G + 0.114 * $p.B) / 255.0
    $r = [int][Math]::Round(255 * (0.13 + 0.87 * $lum))
    $g = [int][Math]::Round(253 * (0.09 + 0.91 * $lum))
    $b = [int][Math]::Round(248 * (0.05 + 0.95 * $lum))
    $out.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($p.A,
      [Math]::Min(255, $r), [Math]::Min(255, $g), [Math]::Min(255, $b)))
  }
}
$src.Dispose()
$out.Save((Join-Path (Get-Location) 'Assets/Images/UI/penjadwalan_card_bg.new.png'),
  [System.Drawing.Imaging.ImageFormat]::Png)
$out.Dispose()
```

Then move `penjadwalan_card_bg.new.png` over `penjadwalan_card_bg.png`. Writing to a temp name first avoids `System.Drawing` holding a lock on the file it is reading.

- [ ] **Step 4: Verify dimensions are unchanged**

Re-run the Step 1 command. Expected: identical output to Step 1. If it differs, restore the backup and fix the script before continuing — a size change silently breaks both `region_rect` call sites.

- [ ] **Step 5: Reimport and screenshot**

Run `filesystem_manage` scan, then open `Scenes/AturJadwal/atur_jadwal.tscn` and take an `editor_screenshot`. Confirm the card and the dialog panel are both cream and the rim still reads.

- [ ] **Step 6: Run the full suite**

Run `test_run` with no suite filter. Expected: all green.

- [ ] **Step 7: Record the placeholder in CLAUDE.md**

Add to `## Outstanding debt & placeholders`:

```markdown
**`penjadwalan_card_bg.png` is a generated recolour (2026-09-10).** The
AturJadwal card and its PERINGATAN dialog share one texture at two
`region_rect`s. The cream version was produced by luminance-mapping the
original olive art with PowerShell + `System.Drawing`, not hand-authored.
Drop-replaceable at the same path — but any replacement must keep the exact
original dimensions, because both call sites address it with hardcoded
`region_rect` values.
```

- [ ] **Step 8: Commit**

```bash
git add Assets/Images/UI/penjadwalan_card_bg.png CLAUDE.md
git commit -m "feat(aturjadwal): recolour the card background from olive to cream

One texture backs both the activity card and the PERINGATAN dialog at
two different region_rects, so replacing it in place fixes both without
touching either call site. Generated recolour, recorded as a placeholder.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: Hairline separators between rows

**Files:**
- Modify: `Scenes/AturJadwal/atur_jadwal.tscn` (via the editor, never by hand)
- Test: `tests/test_cream_panel_tokens.gd` (extend)

**Interfaces:**
- Consumes: `PreviewRowSeparator` from Task 2.
- Produces: nothing code-facing.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_cream_panel_tokens.gd`:

```gdscript
## Source-text scan, following the established pattern for UI that
## cannot be instantiated headlessly. Four separators for five rows.
func test_the_rows_are_divided_by_hairlines() -> void:
	var path := "res://Scenes/AturJadwal/atur_jadwal.tscn"
	var f := FileAccess.open(path, FileAccess.READ)
	assert_not_null(f, "could not open " + path)
	var src := f.get_as_text()
	f.close()
	assert_contains(src, "PreviewRowSeparator",
		"the activity rows should be divided by the hairline variation")
	var count := src.count("PreviewRowSeparator")
	assert_eq(count, 4, "five rows need exactly four separators, found %d" % count)
```

- [ ] **Step 2: Run the test and verify it fails**

Run `test_run` with suite `cream_panel_tokens`.
Expected: FAIL — `PreviewRowSeparator` does not appear in the scene.

- [ ] **Step 3: Open the scene and confirm the row order**

Run `scene_open` on `res://Scenes/AturJadwal/atur_jadwal.tscn`, then `scene_get_hierarchy` scoped to `Penjadwalan/TextureRect/Rows` — a `VBoxContainer` at line 468 holding the five `ActivityRow` instances. Note the five children's names and their order; the separators go between them, so the order determines each `move_node` index.

- [ ] **Step 4: Add four separators**

Use `batch_execute` with `create_node` and `move_node`, parenting each to `Penjadwalan/TextureRect/Rows`. For each of the four gaps:

- type `HSeparator`
- `theme_type_variation` = `PreviewRowSeparator`
- `mouse_filter` = `2` (ignore — the rows are buttons and a separator must not eat taps)

`node_create` appends last, so each separator needs a `move_node` to sit between its two rows. Working back-to-front (the last gap first) keeps earlier indices stable as you insert. Numbers must be unquoted (`1`, not `"1.0"`).

The `VBoxContainer` may carry a `separation` constant that already spaces the rows. If the hairlines land too far apart, adjust that constant — it is layout-only, and layout-only constant overrides are the one accepted exception to the no-`theme_override_*` rule.

- [ ] **Step 5: Save the scene**

Run `scene_save`. Then immediately:

```bash
git diff HEAD -- '*.gd'
```

Expected: empty. `scene_save` flushes the editor's open script buffers over whatever is on disk; if this shows changes to `.gd` files you did not edit, the editor has overwritten them and they must be restored.

- [ ] **Step 6: Run the test and verify it passes**

Run `test_run` with suite `cream_panel_tokens`. Expected: PASS, 7 tests.

- [ ] **Step 7: Screenshot**

`editor_screenshot` on the open scene. Confirm the hairlines sit between rows and the rows no longer carry individual strokes.

- [ ] **Step 8: Run the full suite**

Run `test_run` with no suite filter. Expected: all green, including `test_viewport_editability` — the separators are scene nodes, so `BASELINE` must not move.

- [ ] **Step 9: Commit**

```bash
git add Scenes/AturJadwal/atur_jadwal.tscn tests/test_cream_panel_tokens.gd
git commit -m "feat(aturjadwal): divide the activity rows with hairlines

Four HSeparators on PreviewRowSeparator replace the 3px stroke each row
used to carry. mouse_filter is ignore so they do not eat taps meant for
the row buttons.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### STOP: review gate

**Task 3 and Task 4 complete Section 1 of the spec — the part the mentor actually asked for.**

Take a screenshot of the finished cream card and review it before starting Task 5. The spec's own risk section says the ghost track solves a problem predicted from a sketch rather than observed in a build. Look at the Wirausaha and Libur rows on the cream sheet. If they hold their own without a track, **stop here**: Tasks 5 and 6 are unnecessary, and skipping them saves three placeholder PNGs that would need maintaining.

Do not start Task 5 without a human decision on this.

---

### Task 5: The ghost track

**Files:**
- Create: `Assets/Images/UI/BarFill/track_ghost.png`
- Modify: `Scripts/Design/ThemeFactory.gd` (new `PreviewTrackGhost` variation)
- Modify: `Scripts/AturJadwal/ActivityRow.gd:70-77` (the `is_skill_row` else-branch)
- Modify: `Assets/Images/UI/BarFill/README.md`
- Test: `tests/test_ghost_track.gd` (create)

**Interfaces:**
- Consumes: `tokens.preview_pill_fill` from Task 1.
- Produces: theme type variation `PreviewTrackGhost`. Task 6 renders its watermark on top.

- [ ] **Step 1: Write the failing test**

Create `tests/test_ghost_track.gd`:

```gdscript
@tool
extends McpTestSuite

## The ghost track behind Wirausaha and Libur.
##
## Those two rows have no target stat, so they carry no gauge. On the old
## dark slab that read acceptably. On the cream sheet a row with no track
## collapses beside the three that have one, so they get the same
## silhouette used as a container rather than a meter: a texture whose
## alpha ramps from 0.18 at the left edge to 1.0 at the right.
##
## The ramp is why this must STRETCH rather than TILE. The BarFill
## textures tile (ThemeFactory.gd's _stat_bar_fill), and a horizontal
## alpha ramp sawtooths back to transparent at every repeat if tiled.

const TRACK_PATH := "res://Assets/Images/UI/BarFill/track_ghost.png"
const LEFT_ALPHA := 0.18
const TOLERANCE := 0.03


func suite_name() -> String:
	return "ghost_track"


func test_the_texture_exists_at_the_expected_size() -> void:
	var tex := load(TRACK_PATH) as Texture2D
	assert_not_null(tex, "missing " + TRACK_PATH)
	assert_eq(tex.get_width(), 256, "track_ghost should be 256 wide")
	assert_eq(tex.get_height(), 48, "track_ghost should be 48 tall")


## The whole point of the asset: transparent at the left, solid at the
## right. If this inverts, the empty half is the one that looks filled.
func test_alpha_ramps_left_to_right() -> void:
	var tex := load(TRACK_PATH) as Texture2D
	assert_not_null(tex, "missing " + TRACK_PATH)
	var img := tex.get_image()
	var mid_y := img.get_height() / 2
	var left := img.get_pixel(2, mid_y).a
	var right := img.get_pixel(img.get_width() - 3, mid_y).a
	assert_true(right > left,
		"alpha should rise left to right, got left=%f right=%f" % [left, right])
	assert_true(right > 0.95, "the right end should be solid, got %f" % right)


## The 9-slice left cap is a fixed region; if it is authored at a
## different alpha than the ramp's start, a seam shows at the rounded end.
func test_left_cap_matches_the_ramp_start() -> void:
	var tex := load(TRACK_PATH) as Texture2D
	assert_not_null(tex, "missing " + TRACK_PATH)
	var img := tex.get_image()
	var mid_y := img.get_height() / 2
	var left := img.get_pixel(2, mid_y).a
	assert_true(abs(left - LEFT_ALPHA) < TOLERANCE,
		"left cap alpha should be ~%f, got %f" % [LEFT_ALPHA, left])


func test_the_variation_stretches_rather_than_tiles() -> void:
	var tokens := DesignTokens.load_default()
	assert_not_null(tokens, "design_tokens.tres failed to load")
	var theme := ThemeFactory.build(tokens)
	var box := theme.get_stylebox("panel", "PreviewTrackGhost") as StyleBoxTexture
	assert_not_null(box, "PreviewTrackGhost should be a StyleBoxTexture")
	assert_eq(box.axis_stretch_horizontal, StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH,
		"a horizontal alpha ramp sawtooths if tiled")


## Documents that this asset is deliberately outside test_bar_contrast's
## 0.90 luminance floor. That floor governs BarFill *fill* textures,
## which multiply against an accent colour; a track multiplies nothing.
func test_the_ghost_track_is_not_a_fill_texture() -> void:
	var contrast_src := FileAccess.open("res://tests/test_bar_contrast.gd", FileAccess.READ)
	assert_not_null(contrast_src, "could not open test_bar_contrast.gd")
	var src := contrast_src.get_as_text()
	contrast_src.close()
	assert_false(src.contains("track_ghost"),
		"track_ghost must not be in the fill-texture roster: it is a track, "
		+ "not a fill, and is not multiplied by an accent colour")
```

- [ ] **Step 2: Run the test and verify it fails**

Run `test_run` with suite `ghost_track`.
Expected: FAIL — the texture does not exist.

- [ ] **Step 3: Generate the texture**

```powershell
Add-Type -AssemblyName System.Drawing
$w = 256; $h = 48; $cap = 22
$bmp = New-Object System.Drawing.Bitmap $w, $h
for ($x = 0; $x -lt $w; $x++) {
  if ($x -lt $cap) { $t = 0.0 }
  elseif ($x -ge ($w - $cap)) { $t = 1.0 }
  else { $t = ($x - $cap) / [double]($w - 2 * $cap) }
  $a = [int][Math]::Round(255 * (0.18 + 0.82 * $t))
  for ($y = 0; $y -lt $h; $y++) {
    $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($a, 230, 218, 198))
  }
}
$bmp.Save((Join-Path (Get-Location) 'Assets/Images/UI/BarFill/track_ghost.png'),
  [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
```

The left cap holds `t = 0.0`, so its alpha is exactly the ramp's start value (0.18) and no seam appears. The right cap holds `t = 1.0`, fully solid. `#E6DAC6` is `(230, 218, 198)`.

- [ ] **Step 4: Add the variation**

In `Scripts/Design/ThemeFactory.gd`, after the `PreviewPillFlat` block:

```gdscript
	# -- Wirausaha and Libur have no target, so no gauge. On the cream
	# sheet a row with no track collapses beside the three that have one,
	# so they get the same silhouette as a container: a texture whose
	# alpha ramps from 0.18 at the left to solid at the right. STRETCH,
	# not TILE -- a horizontal ramp sawtooths at every repeat if tiled. --
	var ghost := StyleBoxTexture.new()
	ghost.texture = load("res://Assets/Images/UI/BarFill/track_ghost.png")
	ghost.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	ghost.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	ghost.set_texture_margin_all(22)
	ghost.content_margin_left = tokens.space_sm
	ghost.content_margin_right = tokens.space_sm
	ghost.content_margin_top = tokens.space_xs
	ghost.content_margin_bottom = tokens.space_xs
	theme.add_type("PreviewTrackGhost")
	theme.set_type_variation("PreviewTrackGhost", "PanelContainer")
	theme.set_stylebox("panel", "PreviewTrackGhost", ghost)
```

- [ ] **Step 5: Point the non-skill rows at it**

In `Scripts/AturJadwal/ActivityRow.gd`, the `else` branch of `_ready()` currently assigns `PreviewPillFlat`. Change it:

```gdscript
	else:
		if pill:
			pill.theme_type_variation = &"PreviewTrackGhost"
		if bar:
			bar.get_parent().remove_child(bar)
			bar.free()
```

Update the `##` doc on `is_skill_row` — it says the other rows' chips "sit straight on the container's grey", which is no longer true:

```gdscript
## True for the three rows with a target to progress toward (Akademis,
## SeniBudaya, Olahraga). Those get a StatBar inside a drawn track. The
## other two -- Wirausaha and Libur -- have no target, so they get the
## ghost track instead: the same silhouette used as a container for their
## cost/gain chips rather than as a meter.
```

Also update the file header, which describes "a darker pill inset to its right".

`PreviewPillFlat` is now unused. Leave it in `ThemeFactory.gd` — removing a baked variation is a separate change with its own test implications.

- [ ] **Step 6: Rescan, then rebake**

Run `filesystem_manage` scan first (Task 5 edited a `.gd`), then rebake. If the `.gd` was edited from outside the editor, force the reload with a no-op `script_patch` on `ActivityRow.gd` — add and remove a blank line. It logs a benign `GDScript reload failed with error code 43` and then works.

- [ ] **Step 7: Run the test and verify it passes**

Run `test_run` with suite `ghost_track`. Expected: PASS, 5 tests.

- [ ] **Step 8: Run the full suite**

Run `test_run` with no suite filter. Expected: all green, including `test_bar_contrast` and `test_script_documentation`.

- [ ] **Step 9: Document the asset**

Append to `Assets/Images/UI/BarFill/README.md`:

```markdown
## track_ghost.png

Not a fill — a track. Used by `PreviewTrackGhost` behind the Wirausaha and
Libur rows, which have no target stat and therefore no gauge.

Two rules bind a replacement, and they are different from the fill rules
above:

- **It must stretch, not tile.** The alpha ramps left to right; a tiled ramp
  sawtooths back to transparent at every repeat.
- **The left 22px cap must hold the ramp's starting alpha (0.18)**, or a
  seam shows where the rounded end meets the ramp.

The 0.90 mean-luminance floor does **not** apply. That floor exists because
fill textures multiply against an accent colour; a track multiplies nothing.
```

- [ ] **Step 10: Commit**

```bash
git add Assets/Images/UI/BarFill/track_ghost.png Assets/Images/UI/BarFill/README.md Scripts/Design/ThemeFactory.gd Scripts/AturJadwal/ActivityRow.gd Assets/Theme/kejartes_theme.tres tests/test_ghost_track.gd
git commit -m "feat(aturjadwal): give Wirausaha and Libur a ghost track

Those two rows have no target stat and so no gauge, which left them
collapsing beside the three that do once the sheet went cream. They now
get the same silhouette as a container: a stretched texture whose alpha
ramps from 0.18 to solid, left to right.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: The watermark motif

**Files:**
- Create: `Assets/Images/UI/BarFill/icon_ghost_koin.png`
- Create: `Assets/Images/UI/BarFill/icon_ghost_sabit.png`
- Modify: `Scenes/AturJadwal/ActivityRow.tscn` (via the editor)
- Modify: `Scripts/AturJadwal/ActivityRow.gd` (new `@export`)
- Modify: `CLAUDE.md`
- Test: `tests/test_ghost_track.gd` (extend)

**Interfaces:**
- Consumes: `PreviewTrackGhost` from Task 5.
- Produces: `ActivityRow.watermark_texture: Texture2D`, an `@export` on the scene root. Nothing later consumes it.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_ghost_track.gd`:

```gdscript
const KOIN_PATH := "res://Assets/Images/UI/BarFill/icon_ghost_koin.png"
const SABIT_PATH := "res://Assets/Images/UI/BarFill/icon_ghost_sabit.png"


func test_both_watermark_motifs_exist() -> void:
	assert_not_null(load(KOIN_PATH) as Texture2D, "missing " + KOIN_PATH)
	assert_not_null(load(SABIT_PATH) as Texture2D, "missing " + SABIT_PATH)


## The watermark must read as absent. If it lands at the row icon's
## weight it becomes a second active element competing with the chips.
func test_the_motifs_are_lighter_than_the_row_icon_brown() -> void:
	var row_icon_brown := Color("7A4A2B")
	for path in [KOIN_PATH, SABIT_PATH]:
		var img := (load(path) as Texture2D).get_image()
		var lit := 0.0
		var n := 0
		for y in range(0, img.get_height(), 4):
			for x in range(0, img.get_width(), 4):
				var px := img.get_pixel(x, y)
				if px.a > 0.5:
					lit += px.get_luminance()
					n += 1
		assert_gt(n, 0, path + " appears to be fully transparent")
		var mean: float = lit / float(n)
		assert_true(mean > row_icon_brown.get_luminance(),
			"%s mean luminance %f should be lighter than the row icon" % [path, mean])


## Authored in the scene, not built at runtime -- keeps this clear of
## the test_viewport_editability ratchet.
func test_the_watermark_is_a_scene_node() -> void:
	var f := FileAccess.open("res://Scenes/AturJadwal/ActivityRow.tscn", FileAccess.READ)
	assert_not_null(f, "could not open ActivityRow.tscn")
	var src := f.get_as_text()
	f.close()
	assert_contains(src, "Watermark", "the watermark should be a node in the scene")


func test_the_watermark_is_not_built_in_script() -> void:
	var f := FileAccess.open("res://Scripts/AturJadwal/ActivityRow.gd", FileAccess.READ)
	assert_not_null(f, "could not open ActivityRow.gd")
	var src := f.get_as_text()
	f.close()
	assert_false(src.contains("TextureRect.new()"),
		"the watermark must be authored in the scene, not constructed at runtime")
```

Note: the last assertion will fail against the *current* file, which builds chip icons with `TextureRect.new()` in `refresh()`. That construction is per-call dynamic content and legitimately belongs in `ALLOWED`. Before implementing, check `tests/test_viewport_editability.gd`'s `ALLOWED` dict for `ActivityRow.gd`. If it is already listed there, narrow this test to scan only `_ready()` rather than the whole file, or drop it and rely on `test_the_watermark_is_a_scene_node`. Do not weaken `ALLOWED` to make this pass.

- [ ] **Step 2: Run the test and verify it fails**

Run `test_run` with suite `ghost_track`. Expected: FAIL — the motifs do not exist.

- [ ] **Step 3: Generate the two motifs**

64x64 transparent PNGs, motif drawn in `#C9B694` = `(201, 182, 148)`.

```powershell
Add-Type -AssemblyName System.Drawing
$ink = [System.Drawing.Color]::FromArgb(255, 201, 182, 148)
$pen = New-Object System.Drawing.Pen $ink, 5
$brush = New-Object System.Drawing.SolidBrush $ink

$koin = New-Object System.Drawing.Bitmap 64, 64
$g = [System.Drawing.Graphics]::FromImage($koin)
$g.SmoothingMode = 'AntiAlias'
$g.DrawEllipse($pen, 10, 10, 44, 44)
$g.DrawEllipse($pen, 22, 22, 20, 20)
$g.Dispose()
$koin.Save((Join-Path (Get-Location) 'Assets/Images/UI/BarFill/icon_ghost_koin.png'),
  [System.Drawing.Imaging.ImageFormat]::Png)
$koin.Dispose()

$sabit = New-Object System.Drawing.Bitmap 64, 64
$g = [System.Drawing.Graphics]::FromImage($sabit)
$g.SmoothingMode = 'AntiAlias'
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$path.AddEllipse(8, 8, 48, 48)
$inner = New-Object System.Drawing.Drawing2D.GraphicsPath
$inner.AddEllipse(24, 4, 44, 44)
$region = New-Object System.Drawing.Region $path
$region.Exclude($inner)
$g.FillRegion($brush, $region)
$g.Dispose()
$sabit.Save((Join-Path (Get-Location) 'Assets/Images/UI/BarFill/icon_ghost_sabit.png'),
  [System.Drawing.Imaging.ImageFormat]::Png)
$sabit.Dispose()
$pen.Dispose(); $brush.Dispose()
```

- [ ] **Step 4: Add the `@export`**

In `Scripts/AturJadwal/ActivityRow.gd`, beside the other texture exports:

```gdscript
## The ghosted motif at the solid right end of the ghost track, on the
## two rows that have no gauge. Null on skill rows, which draw a bar
## there instead. Assigned per row in atur_jadwal.tscn.
@export var watermark_texture: Texture2D:
	set(value):
		watermark_texture = value
		if is_inside_tree():
			var mark := get_node_or_null("Container/Pill/Watermark") as TextureRect
			if mark:
				mark.texture = value
				mark.visible = value != null
```

And in `_ready()`, inside the existing `else` branch after the variation assignment:

```gdscript
		var mark := get_node_or_null("Container/Pill/Watermark") as TextureRect
		if mark:
			mark.texture = watermark_texture
			mark.visible = watermark_texture != null
```

In the `if is_skill_row:` branch, hide it — skill rows draw a bar in that space:

```gdscript
		var skill_mark := get_node_or_null("Container/Pill/Watermark") as TextureRect
		if skill_mark:
			skill_mark.visible = false
```

- [ ] **Step 5: Add the node to `ActivityRow.tscn`**

Scene work before script work. Run `scene_open` on `res://Scenes/AturJadwal/ActivityRow.tscn`, then `batch_execute`:

- `create_node`: `TextureRect` named `Watermark`, parent `Container/Pill`
- `set_property`: `mouse_filter` = `2`
- `set_property`: `expand_mode` = `1`
- `set_property`: `stretch_mode` = `5`
- `set_property`: anchors — `anchor_left` `1`, `anchor_right` `1`, `anchor_top` `0.5`, `anchor_bottom` `0.5` (`anchors_preset` is inert; set the four anchors)
- `set_property`: `offset_left` `-56`, `offset_right` `-8`, `offset_top` `-24`, `offset_bottom` `24`
- `move_node`: to index `0` within `Container/Pill`, so it draws behind `Chips`

Then `scene_save`, and immediately:

```bash
git diff HEAD -- '*.gd'
```

Expected: empty apart from `ActivityRow.gd` if you have already made the Step 4 edit. If other `.gd` files appear, the editor has flushed stale buffers over them — restore before continuing.

- [ ] **Step 6: Assign the two textures per row**

In `atur_jadwal.tscn`, set `watermark_texture` on the Wirausaha row instance to `icon_ghost_koin.png` and on the Libur row instance to `icon_ghost_sabit.png`.

Set these on the **instance roots**, not on their children — overrides serialise only on an instanced scene's root, which is exactly why `watermark_texture` is an `@export` on `ActivityRow` rather than a property reached into `Container/Pill/Watermark`. Save, then verify both values survived by reopening the scene and reading them back.

- [ ] **Step 7: Rescan and rebake**

Scan, force the script reload if needed, rebake.

- [ ] **Step 8: Run the test and verify it passes**

Run `test_run` with suite `ghost_track`. Expected: PASS.

- [ ] **Step 9: Screenshot**

Open `atur_jadwal.tscn`, `editor_screenshot`. Confirm the motif sits at the solid right end of both ghost tracks, reads as faded, and does not collide with the chips.

- [ ] **Step 10: Run the full suite**

Run `test_run` with no suite filter. Expected: all green, `test_viewport_editability`'s `BASELINE` unchanged.

- [ ] **Step 11: Record the placeholders in CLAUDE.md**

Add to `## Outstanding debt & placeholders`:

```markdown
**Ghost-track assets are generated geometry (2026-09-10).**
`Assets/Images/UI/BarFill/track_ghost.png` and the two motifs
`icon_ghost_koin.png` / `icon_ghost_sabit.png` were produced with PowerShell +
`System.Drawing`, not hand-authored. Drop-replaceable at the same paths. The
track's two constraints are in that folder's README: it must stretch rather
than tile, and its left 22px cap must hold the ramp's 0.18 starting alpha.
```

- [ ] **Step 12: Commit**

```bash
git add Assets/Images/UI/BarFill/icon_ghost_koin.png Assets/Images/UI/BarFill/icon_ghost_sabit.png Scenes/AturJadwal/ActivityRow.tscn Scenes/AturJadwal/atur_jadwal.tscn Scripts/AturJadwal/ActivityRow.gd CLAUDE.md tests/test_ghost_track.gd
git commit -m "feat(aturjadwal): watermark the ghost track with its category motif

The coin and crescent sit at the track's solid right end in a light
#C9B694, a step below the row icon's brown, so they read as absent
rather than as a second active element. Authored as a scene node.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 7: The press inset

**Files:**
- Modify: `Scripts/AturJadwal/ActivityRow.gd`
- Test: `tests/test_cream_panel_tokens.gd` (extend)

**Interfaces:**
- Consumes: `PreviewRowPressed` from Task 2.
- Produces: nothing.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_cream_panel_tokens.gd`:

```gdscript
## Panel has no pressed state, so the sink is driven from the Button
## that wraps it. Signal wiring stays ungated by Engine.is_editor_hint
## so this can be exercised without instantiating the scene.
func test_the_row_wires_its_own_press_state() -> void:
	var f := FileAccess.open("res://Scripts/AturJadwal/ActivityRow.gd", FileAccess.READ)
	assert_not_null(f, "could not open ActivityRow.gd")
	var src := f.get_as_text()
	f.close()
	assert_contains(src, "button_down.connect",
		"Panel has no pressed state; the row must drive it from the Button")
	assert_contains(src, "button_up.connect",
		"a press with no release leaves the row stuck sunken")
	assert_contains(src, "PreviewRowPressed",
		"the press should swap to the baked pressed variation")


func test_the_row_is_a_button() -> void:
	var f := FileAccess.open("res://Scripts/AturJadwal/ActivityRow.gd", FileAccess.READ)
	assert_not_null(f, "could not open ActivityRow.gd")
	var src := f.get_as_text()
	f.close()
	assert_contains(src, "extends Button",
		"the whole row is the tap target")
```

- [ ] **Step 2: Run the test and verify it fails**

Run `test_run` with suite `cream_panel_tokens`.
Expected: FAIL on `button_down.connect`.

- [ ] **Step 3: Wire the press**

In `Scripts/AturJadwal/ActivityRow.gd`, add to `_ready()`. Keep this **ungated** by `Engine.is_editor_hint()` — pure signal wiring stays ungated so tests can exercise it; only real side effects get gated.

```gdscript
	button_down.connect(_on_row_pressed)
	button_up.connect(_on_row_released)
```

And the two handlers:

```gdscript
## Panel has no pressed state of its own, so the row's Button drives it.
## Swapping the variation rather than tweening a colour keeps the change
## in the theme where the rest of the row's styling lives.
func _on_row_pressed() -> void:
	var container := get_node_or_null("Container") as Panel
	if container:
		container.theme_type_variation = &"PreviewRowPressed"


## Paired with _on_row_pressed. Without this the row stays sunken after
## the first tap.
func _on_row_released() -> void:
	var container := get_node_or_null("Container") as Panel
	if container:
		container.theme_type_variation = &"PreviewRow"
```

- [ ] **Step 4: Rescan and run the test**

Scan, force the script reload if needed, then run `test_run` with suite `cream_panel_tokens`.
Expected: PASS.

- [ ] **Step 5: Verify the press by hand**

`project_run`, then use the debug overlay: F1 (or five taps top-right) → General → **⚡ Seed Playtest State**, then Scenes → AturJadwal. Do not play to reach this state.

To tap a row: read its `global_rect` via `game_manage(op="get_ui_elements", params={"root_path": "/root/AturJadwal/Penjadwalan", "max_depth": 3})` — always scope the call, never run it bare. Send a `motion` event to the target first (Godot will not route a click without the hover state), then the `button` press. Rescale coordinates: `global_rect` is in the 1080-wide design space, input events take window pixels, and `editor_screenshot` reports the real window size as `original_width` — so `window_x = global_x * original_width / 1080`.

Confirm the row sinks on press and returns on release.

- [ ] **Step 6: Run the full suite**

Run `test_run` with no suite filter. Expected: all green.

- [ ] **Step 7: Commit**

```bash
git add Scripts/AturJadwal/ActivityRow.gd tests/test_cream_panel_tokens.gd
git commit -m "feat(aturjadwal): sink the activity row on press

Panel carries no pressed state, so the row's Button swaps the
container's variation on button_down/button_up. Without the paired
release the row stays sunken after the first tap.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 8: Confirm-pair semantics

Independent of Tasks 1–7 — shares no tokens, scenes or tests with them, and can run in parallel or be skipped. Cosmetic only: `theme_type_variation` selects a styling entry and has no bearing on input routing, `pressed` signals, or logic. Nothing here touches a `.connect()` or a handler.

Excluded, both already correct: `Scenes/Minigames/UI/QuitConfirmDialog.tscn` (already `DangerButton` + `SecondaryButton` on a genuinely destructive action) and `Scripts/Minigames/UI/BaseMinigame.gd` (mentions `DangerButton` only in a `##` doc comment on a null-defaulting `Texture2D` export).

**Files:**
- Modify: `Scenes/AturJadwal/atur_jadwal.tscn:430,440`
- Modify: `Scripts/CutScene/cut_scene.gd:116,205`
- Modify: `Scenes/Inventory/ApplyItemScreen.tscn`, `Scenes/Lobby/loby.tscn`, `Scenes/SchoolSimulation/EventStudentSelectDialog.tscn`, `Scenes/StudentCard/student_card.tscn`, `Scenes/StudentList/student_list.tscn` — audit each
- Test: `tests/test_confirm_pair_semantics.gd` (create)

**Interfaces:**
- Consumes: existing `PrimaryButton`, `SecondaryButton`, `DangerButton`, `SuccessButton`.
- Produces: nothing.

- [ ] **Step 1: Audit every call site**

```bash
cd "C:/Users/Legion/Documents/KEJARTES/new-game-project"
grep -rn "SuccessButton\|DangerButton" Scenes/ Scripts/ | grep -v ThemeFactory | grep -v DesignTokens
```

For each hit, classify against the spec's table and write the classification into the commit message:

| Case | Variation |
|---|---|
| Genuinely destructive — discards progress | `DangerButton` |
| Ordinary confirm | `PrimaryButton` + `SecondaryButton` |
| Something is earned, not confirmed | `SuccessButton` |

Two are known misuses: `cut_scene.gd:116` styles a **skip** as danger; `cut_scene.gd:205` styles the **grade 9 selection** as danger. Neither discards anything.

- [ ] **Step 2: Write the failing test**

Create `tests/test_confirm_pair_semantics.gd`:

```gdscript
@tool
extends McpTestSuite

## Red and green mean something specific, or they mean nothing.
##
## Before 2026-09-10 every confirm was a green/red pair regardless of
## what was being confirmed, which spent the loudest colours in the
## palette on ordinary "carry on?" prompts. DangerButton is now reserved
## for actions that actually discard something.
##
## Source-text scans, following the established pattern: most of this UI
## cannot be instantiated headlessly.

## Scenes whose confirms are ordinary, not destructive. None of these
## should carry DangerButton after this pass.
const NON_DESTRUCTIVE_SCENES := [
	"res://Scenes/AturJadwal/atur_jadwal.tscn",
	"res://Scenes/SchoolSimulation/EventStudentSelectDialog.tscn",
	"res://Scenes/Inventory/ApplyItemScreen.tscn",
]

## The one scene that legitimately keeps it: quitting a minigame
## discards the run in progress.
const DESTRUCTIVE_SCENE := "res://Scenes/Minigames/UI/QuitConfirmDialog.tscn"


func suite_name() -> String:
	return "confirm_pair_semantics"


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var src := f.get_as_text()
	f.close()
	return src


func test_ordinary_confirms_do_not_use_danger() -> void:
	for path in NON_DESTRUCTIVE_SCENES:
		var src := _read(path)
		assert_ne(src, "", "could not open " + path)
		assert_false(src.contains("DangerButton"),
			"%s is an ordinary confirm and should not use DangerButton" % path)


func test_ordinary_confirms_pair_primary_with_secondary() -> void:
	var src := _read("res://Scenes/AturJadwal/atur_jadwal.tscn")
	assert_ne(src, "", "could not open atur_jadwal.tscn")
	assert_contains(src, "PrimaryButton",
		"the PERINGATAN confirm needs one filled affirmative")
	assert_contains(src, "SecondaryButton",
		"the PERINGATAN confirm needs one quiet negative")


## The point of the split: red still exists where it is earned.
func test_the_destructive_confirm_keeps_danger() -> void:
	var src := _read(DESTRUCTIVE_SCENE)
	assert_ne(src, "", "could not open " + DESTRUCTIVE_SCENE)
	assert_contains(src, "DangerButton",
		"quitting a minigame discards the run; it should stay red")


func test_the_cutscene_skip_is_not_styled_as_destructive() -> void:
	var src := _read("res://Scripts/CutScene/cut_scene.gd")
	assert_ne(src, "", "could not open cut_scene.gd")
	assert_false(src.contains("DangerButton"),
		"skipping a cutscene and picking a grade discard nothing")
```

- [ ] **Step 3: Run the test and verify it fails**

Run `test_run` with suite `confirm_pair_semantics`.
Expected: FAIL — `atur_jadwal.tscn` carries `SuccessButton` and `DangerButton`; `cut_scene.gd` carries two `DangerButton` assignments.

- [ ] **Step 4: Fix the AturJadwal dialog**

Scene work first. `scene_open` on `res://Scenes/AturJadwal/atur_jadwal.tscn`, then set `theme_type_variation` on `Peringatan/TextureRect/ButtonYes` to `PrimaryButton` and on `ButtonNo` to `SecondaryButton`. `scene_save`, then check `git diff HEAD -- '*.gd'` is empty.

- [ ] **Step 5: Fix the remaining scenes**

Apply the same treatment to each scene the Step 1 audit classified as an ordinary confirm. Leave `SuccessButton` where something is genuinely earned rather than confirmed.

- [ ] **Step 6: Fix the cutscene script**

In `Scripts/CutScene/cut_scene.gd`, change line 116 to `&"SecondaryButton"` — a skip is a quiet opt-out, not a warning. Change the grade-9 button at line 205 to `&"PrimaryButton"` — selecting the hardest grade is a choice, not a destructive act.

Do **not** touch the emoji on line 205 in this task. It violates the 2026-09-02 iconography ban and is recorded in the spec's non-goals as separate work; changing it here would put an unrelated fix in this commit.

- [ ] **Step 7: Rescan and run the test**

Scan, force the script reload if needed, then run `test_run` with suite `confirm_pair_semantics`.
Expected: PASS, 4 tests.

- [ ] **Step 8: Screenshot every affected screen**

Contrast is the one failure mode tests cannot catch: a button rendering cream-on-cream stays fully tappable but its label becomes hard to read. Seed and teleport rather than playing — debug overlay → **⚡ Seed Playtest State**, then the Scenes tab.

Screenshot each of: AturJadwal's PERINGATAN dialog, the Lobby, StudentCard, StudentList, ApplyItemScreen, and the event-select dialog. Confirm every button label is legible against its new fill.

- [ ] **Step 9: Run the full suite**

Run `test_run` with no suite filter. Expected: all green.

- [ ] **Step 10: Commit**

```bash
git add Scenes/ Scripts/CutScene/cut_scene.gd tests/test_confirm_pair_semantics.gd
git commit -m "refactor(ui): split the confirm pair by meaning instead of colour

Every confirm was a green/red pair regardless of what was being
confirmed, which spent the palette's loudest colours on ordinary
'carry on?' prompts and left nothing louder for the destructive ones.
DangerButton is now reserved for actions that discard something --
which in practice means the minigame quit dialog, already correct and
untouched. The cutscene skip and the grade-9 selection were both styled
as danger and discard nothing.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 9: Changelog and guide

**Files:**
- Modify: `docs/superpowers/CHANGELOG.md`
- Modify: `CLAUDE.md` (`## Current work`)

- [ ] **Step 1: Write the changelog entry**

Add newest-first to `docs/superpowers/CHANGELOG.md`: what changed, which sections landed, which were skipped at the review gate, and every placeholder left behind (the recoloured card background, the ghost track, the two motifs).

- [ ] **Step 2: Update `## Current work` in CLAUDE.md**

Remove this pass from `## Current work` — completed passes get a changelog entry, not a paragraph in the guide. Confirm the placeholder entries added in Tasks 3 and 6 are present and accurate under `## Outstanding debt & placeholders`.

Check the file is still under its 20,000-character soft budget:

```bash
wc -c CLAUDE.md
```

- [ ] **Step 3: Run the full suite one last time**

Run `test_run` with no suite filter. Expected: all green. Record the final suite and test counts — the guide's "65 suites, 960 tests" line needs updating for the two or three suites this plan adds.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/CHANGELOG.md CLAUDE.md
git commit -m "docs: record the cream panel language pass

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```
