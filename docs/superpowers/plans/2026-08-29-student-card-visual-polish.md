# Student Card Visual Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Revert the info badge's green tint, and make the "Sifat Pasif" trait pills read as the mockup's gold buttons with outlined white text.

**Architecture:** Both defects share one root cause — `modulate` on a texture *multiplies* against the art instead of replacing its colour, so tinting a mid-grey pill gold yields dark olive and tinting an amber glyph green yields dark moss. The fix is to stop tinting at draw time: drop the badge's `modulate` entirely, and bake the gold into `trait_button.png` itself so the stylebox can draw it untinted and its purple border survives.

**Tech Stack:** Godot 4.6, GDScript, the in-editor `McpTestSuite` runner, `System.Drawing` via PowerShell for the one-shot asset recolour.

**Spec:** No spec document — this plan implements two directives given directly with a reference mockup:
1. "undo the info icon near the academic/athletic icon color"
2. "adjust the sifat pasif button so it look like the example pic"

## Global Constraints

- Godot **4.6**, GDScript.
- **Never add a `theme_override_*`.** Styling changes go in `Scripts/Design/ThemeFactory.gd` as a type variation, then the theme is rebaked to `Assets/Theme/kejartes_theme.tres`.
- Colours come from `DesignTokens` fields, never hardcoded hex in `ThemeFactory.gd`.
- `ThemeFactory.build()` must tolerate null font slots — `tests/test_theme_factory.gd` builds with `font_display = null`, so every `set_font` call needs an `if tokens.font_display != null:` guard.
- Test suites live in `tests/test_*.gd`, extend `McpTestSuite`, must be `@tool`, and **no test may be a coroutine**.
- **The Godot MCP bridge is single-client.** Implementer subagents must never call `mcp__godot-ai__*`; the controller runs every scan, rebake, test run, and screenshot.
- After editing any `.gd` or image asset, the controller runs `filesystem_manage(op="scan")` before `test_run`.
- Conventional Commits with a scope.

## Known baseline

The full suite is **307 passed / 1 failed**. The single failure is `audio_director / test_volumes_persist_across_a_fresh_director`, a pre-existing coroutine bug documented in CLAUDE.md Known Issues. It is unrelated to this work — do not try to fix it, and do not treat it as a regression.

## Measured facts this plan is built on

Sampled from `Assets/Images/StudentCard/trait_button.png` (640×640) inside the stylebox's `region_rect` of `Rect2(20, 277, 601, 91)`:

| What | Value |
|---|---|
| Border colour | `RGB(61, 32, 72)` = `#3D2048`, saturation ≈ 0.56 |
| Fill gradient, top of pill | `RGB(111, 111, 111)` → v ≈ 0.435 |
| Fill gradient, bottom of pill | `RGB(61, 61, 61)` → v ≈ 0.24 |
| Top bevel highlight | `RGB(246, 246, 246)` → v ≈ 0.965 |

The fill is **pure grey** (R = G = B, saturation 0); the border is **saturated purple**. Saturation cleanly separates the two, which is what lets the recolour repaint the fill while leaving the border untouched.

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `Scripts/StudentCard/StudentCardView.gd` | Builds the icon cluster and its info badge. | Modify — delete one line |
| `tests/test_student_card_layout.gd` | Pins the card's layout and asset contract. | Modify — one new test |
| `Assets/Images/StudentCard/trait_button.png` | The trait pill's 9-slice art. | Modify — recoloured in place |
| `Scripts/Design/ThemeFactory.gd` | Builds every theme type variation. | Modify — `TraitPill` block |
| `Assets/Theme/kejartes_theme.tres` | The baked theme the game loads. | Regenerate |
| `tests/test_theme_factory.gd` | Pins theme variation contracts. | Modify — two new tests |

**Task order.** Task 1 is a one-line revert, independent of everything else. Task 2 recolours the asset and restyles the pill's text together, because the text colour choice (white + dark outline) only makes sense against the gold fill — a reviewer judging one without the other would be guessing.

---

# Task 1: The info badge draws its own colour again

**Files:**
- Modify: `Scripts/StudentCard/StudentCardView.gd:204`
- Test: `tests/test_student_card_layout.gd`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: nothing other tasks depend on.

`build_icon_clusters` currently tints the info badge with `state_success` green. Because `modulate` multiplies, the amber `icon_info.png` glyph becomes dark moss rather than the mockup's clean green — worse than either the original or the target. This task restores the untinted asset.

**A note for the reviewer, so this is not "helpfully" undone:** the reference mockup *does* show green badges, and this task deliberately does not deliver that. Matching the mockup's badge needs a **new asset** — its badge is a filled green disc with a white glyph, whereas `icon_info.png` is an amber ring with an amber glyph. No amount of `modulate` turns one into the other. Reverting to the shipped amber is the explicit instruction; a green badge asset is separate future work.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_student_card_layout.gd`:

```gdscript
## The info badge wears icon_info.png's own colour. Tinting it via modulate
## multiplies against the art instead of replacing it, so the amber glyph
## goes muddy rather than changing hue. Matching the mockup's green badge
## needs a different asset, not a tint.
func test_info_badge_draws_its_asset_untinted() -> void:
	var src := FileAccess.get_file_as_string(
		"res://Scripts/StudentCard/StudentCardView.gd")
	assert_false(src.contains("badge.modulate"),
		"the info badge must draw icon_info.png untinted")
```

- [ ] **Step 2: Run it and confirm it fails**

**Controller action:** `filesystem_manage(op="scan")` then `test_run(suite="student_card_layout")`.
Expected: FAIL on `test_info_badge_draws_its_asset_untinted` — `StudentCardView.gd` still contains `badge.modulate`.

- [ ] **Step 3: Delete the tint**

In `Scripts/StudentCard/StudentCardView.gd`, inside `build_icon_clusters`, remove the single line:

```gdscript
			badge.modulate = DesignTokens.load_default().state_success
```

The surrounding block becomes:

```gdscript
			var badge := TextureRect.new()
			badge.name = "InfoBadge"
			badge.texture = load(_CARD_ART + "icon_info.png")
			badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
```

Nothing else in the function changes.

- [ ] **Step 4: Run it and confirm it passes**

**Controller action:** `filesystem_manage(op="scan")` then `test_run(suite="student_card_layout")`.
Expected: PASS, 17 tests.

- [ ] **Step 5: Run the full suite**

**Controller action:** `test_run()`.
Expected: **307 passed, 1 failed** — the known `audio_director` bug only.

- [ ] **Step 6: Commit**

```bash
git add Scripts/StudentCard/StudentCardView.gd tests/test_student_card_layout.gd
git commit -m "fix(student-card): stop tinting the info badge, restore its asset colour"
```

---

# Task 2: The trait pills read as the mockup's gold buttons

**Files:**
- Modify: `Assets/Images/StudentCard/trait_button.png`
- Modify: `Scripts/Design/ThemeFactory.gd:279-293`
- Modify: `Assets/Theme/kejartes_theme.tres` (regenerated, not hand-edited)
- Test: `tests/test_theme_factory.gd`

**Interfaces:**
- Consumes: `DesignTokens.currency_gold`, `.text_on_brand`, `.text_primary`, `.font_h2`, `.font_display`.
- Produces: a `TraitPill` variation whose `normal` stylebox is an untinted `StyleBoxTexture`, with `font_color` = `text_on_brand`, `font_outline_color` = `text_primary`, and `outline_size` = 6.

Two changes that only make sense together:

1. **The art ships gold.** `modulate_color = tokens.currency_gold` multiplies against a fill of ~0.435 grey, giving `0.435 × #ffc93c` ≈ `RGB(111, 87, 26)` — dark olive, not gold. It also multiplies the `#3D2048` purple border into brown. Baking the gold into the texture and drawing it untinted fixes both at once.
2. **The text gains an outline.** The mockup's label is chunky white with a dark rim. White-on-gold has poor contrast unaided, and the card's other display text (`CardSectionLabel`) already uses exactly this white-fill/dark-outline treatment — so this keeps the card internally consistent.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_theme_factory.gd`:

```gdscript
## The pill's art ships gold with a dark purple border baked in. A stylebox
## tint would multiply against both -- muddying the fill to olive and
## turning the purple border brown -- so the texture must draw untinted.
func test_trait_pill_draws_its_art_untinted() -> void:
	var theme := ThemeFactory.build(DesignTokens.load_default())
	var normal := theme.get_stylebox("normal", "TraitPill")
	assert_true(normal is StyleBoxTexture,
		"TraitPill's normal stylebox must be the pill texture")
	assert_eq((normal as StyleBoxTexture).modulate_color, Color.WHITE,
		"TraitPill must not tint its texture")


## White text on a gold fill needs the dark rim to stay legible, matching
## the treatment CardSectionLabel already uses on the same card.
func test_trait_pill_text_is_outlined() -> void:
	var tokens := DesignTokens.load_default()
	var theme := ThemeFactory.build(tokens)
	assert_eq(theme.get_color("font_color", "TraitPill"), tokens.text_on_brand,
		"TraitPill text must be white")
	assert_eq(theme.get_color("font_outline_color", "TraitPill"), tokens.text_primary,
		"TraitPill text must carry the dark outline")
	assert_true(theme.get_constant("outline_size", "TraitPill") > 0,
		"TraitPill's outline must have width")
```

- [ ] **Step 2: Run them and confirm they fail**

**Controller action:** `filesystem_manage(op="scan")` then `test_run(suite="theme_factory")`.
Expected: both new tests FAIL — `modulate_color` is currently `currency_gold`, and no outline colour or size is set on `TraitPill`.

- [ ] **Step 3: Recolour the pill texture**

This is a one-shot asset transform, not project code — write it to the scratchpad, not the repo. Git history preserves the original grey art if the result needs re-deriving.

Save as `<scratchpad>/recolour_trait_button.ps1` and run it once:

```powershell
Add-Type -AssemblyName System.Drawing

$path = "C:\Users\ASUS\Downloads\KejarTestAlphaVer2.15\new-game-project\Assets\Images\StudentCard\trait_button.png"

# Anchored on the currency_gold token (#ffc93c).
$goldR = 255.0; $goldG = 201.0; $goldB = 60.0
# Deep end of the gradient: currency_gold at 72% value.
$deepR = 184.0; $deepG = 145.0; $deepB = 43.0
# Top bevel: currency_gold lifted 75% toward white.
$hiR = 255.0; $hiG = 241.0; $hiB = 206.0

# The fill's own grey gradient runs 0.24 (bottom) -> 0.435 (top);
# anything brighter than that is the bevel highlight.
$vLo = 0.24; $vHi = 0.435

$bmp = [System.Drawing.Bitmap]::FromFile($path)
$w = $bmp.Width; $h = $bmp.Height
$rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
$data = $bmp.LockBits($rect,
    [System.Drawing.Imaging.ImageLockMode]::ReadWrite,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$len = $data.Stride * $h
$bytes = New-Object byte[] $len
[System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $len)

for ($i = 0; $i -lt $len; $i += 4) {
    # Format32bppArgb is laid out B, G, R, A in memory.
    $b = [double]$bytes[$i]
    $g = [double]$bytes[$i + 1]
    $r = [double]$bytes[$i + 2]
    if ($bytes[$i + 3] -eq 0) { continue }

    $mx = [Math]::Max($r, [Math]::Max($g, $b))
    $mn = [Math]::Min($r, [Math]::Min($g, $b))
    if ($mx -eq 0) { $sat = 0.0 } else { $sat = ($mx - $mn) / $mx }

    # Pure grey (sat 0) is fill; the purple border sits near 0.56. Pixels
    # in between are antialiased edges and blend proportionally.
    $t = [Math]::Min(1.0, $sat / 0.4)
    $v = $mx / 255.0

    if ($v -le $vLo) {
        $s = $v / $vLo
        $ar = $deepR * $s; $ag = $deepG * $s; $ab = $deepB * $s
    } elseif ($v -le $vHi) {
        $t2 = ($v - $vLo) / ($vHi - $vLo)
        $ar = $deepR + ($goldR - $deepR) * $t2
        $ag = $deepG + ($goldG - $deepG) * $t2
        $ab = $deepB + ($goldB - $deepB) * $t2
    } else {
        $t3 = ($v - $vHi) / (1.0 - $vHi)
        $ar = $goldR + ($hiR - $goldR) * $t3
        $ag = $goldG + ($hiG - $goldG) * $t3
        $ab = $goldB + ($hiB - $goldB) * $t3
    }

    $nr = [int][Math]::Round($ar + ($r - $ar) * $t)
    $ng = [int][Math]::Round($ag + ($g - $ag) * $t)
    $nb = [int][Math]::Round($ab + ($b - $ab) * $t)

    $bytes[$i]     = [byte][Math]::Max(0, [Math]::Min(255, $nb))
    $bytes[$i + 1] = [byte][Math]::Max(0, [Math]::Min(255, $ng))
    $bytes[$i + 2] = [byte][Math]::Max(0, [Math]::Min(255, $nr))
}

[System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $data.Scan0, $len)
$bmp.UnlockBits($data)

$tmp = $path + ".tmp.png"
$bmp.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Move-Item -Force $tmp $path
Write-Host "recoloured $path"
```

- [ ] **Step 4: Verify the recolour hit its marks**

Run this and check the numbers before trusting the art:

```powershell
Add-Type -AssemblyName System.Drawing
$bmp = [System.Drawing.Bitmap]::FromFile("C:\Users\ASUS\Downloads\KejarTestAlphaVer2.15\new-game-project\Assets\Images\StudentCard\trait_button.png")
foreach ($p in @(@(320,322),@(320,290),@(320,350),@(20,322),@(618,322))) {
  $c = $bmp.GetPixel($p[0], $p[1])
  Write-Host ("({0},{1}) R={2} G={3} B={4}" -f $p[0], $p[1], $c.R, $c.G, $c.B)
}
$bmp.Dispose()
```

Expected: the three fill samples at `x=320` come back gold (red channel well above blue — roughly `R≈229 G≈181 B≈54` at `y=322`), and **both border samples stay `R=61 G=32 B=72`**. An unchanged purple border is the check that matters; if the border shifted, the saturation threshold is wrong and the fill mask leaked.

- [ ] **Step 5: Rewrite the `TraitPill` block**

In `Scripts/Design/ThemeFactory.gd`, replace the block currently spanning lines 279-293:

```gdscript
	# -- Trait button: one recolourable pill, tinted by the caller. --
	theme.add_type("TraitPill")
	theme.set_type_variation("TraitPill", "Button")

	var trait_normal := StyleBoxTexture.new()
	trait_normal.texture = load(_CARD_ART + "trait_button.png")
	trait_normal.region_rect = Rect2(20, 277, 601, 91)
	trait_normal.set_texture_margin_all(45)
	trait_normal.modulate_color = tokens.currency_gold
	theme.set_stylebox("normal", "TraitPill", trait_normal)
	theme.set_stylebox("hover", "TraitPill", trait_normal)
	theme.set_stylebox("pressed", "TraitPill", trait_normal)
	theme.set_stylebox("focus", "TraitPill", StyleBoxEmpty.new())
	theme.set_font_size("font_size", "TraitPill", tokens.font_body_size)
	theme.set_color("font_color", "TraitPill", tokens.text_on_brand)
```

with:

```gdscript
	# -- Trait button ("Sifat Pasif" pills): the art ships gold with its own
	# purple border, so the stylebox draws it untinted. A modulate here
	# multiplies against the texture rather than replacing its colour --
	# it would mud the fill to olive and turn the border brown. --
	theme.add_type("TraitPill")
	theme.set_type_variation("TraitPill", "Button")

	var trait_normal := StyleBoxTexture.new()
	trait_normal.texture = load(_CARD_ART + "trait_button.png")
	trait_normal.region_rect = Rect2(20, 277, 601, 91)
	trait_normal.set_texture_margin_all(45)
	theme.set_stylebox("normal", "TraitPill", trait_normal)
	theme.set_stylebox("hover", "TraitPill", trait_normal)
	theme.set_stylebox("pressed", "TraitPill", trait_normal)
	theme.set_stylebox("focus", "TraitPill", StyleBoxEmpty.new())
	theme.set_font_size("font_size", "TraitPill", tokens.font_h2)
	theme.set_color("font_color", "TraitPill", tokens.text_on_brand)
	theme.set_constant("outline_size", "TraitPill", 6)
	theme.set_color("font_outline_color", "TraitPill", tokens.text_primary)
	if tokens.font_display != null:
		theme.set_font("font", "TraitPill", tokens.font_display)
```

The `if tokens.font_display != null:` guard is not optional — `test_theme_factory.gd`'s `build must tolerate unassigned font slots` test calls `ThemeFactory.build()` with `font_display = null`, and an unguarded `set_font` would break it.

- [ ] **Step 6: Rebake the theme**

`Scripts/Design/BakeTheme.gd` is an `EditorScript` normally run with File > Run (Ctrl+Shift+X), which is not reachable over MCP. Run its body in the live game instead.

**Controller action:** `filesystem_manage(op="scan")`, then `project_run(mode="main")`, then:

```gdscript
var tokens = DesignTokens.load_default()
var theme = ThemeFactory.build(tokens)
var err = ResourceSaver.save(theme, "res://Assets/Theme/kejartes_theme.tres")
return {"err": err}
```

via `editor_manage(op="game_eval")`. Expected: `{"err": 0}`. Then `project_manage(op="stop")` and `filesystem_manage(op="scan")`.

- [ ] **Step 7: Run the tests and confirm they pass**

**Controller action:** `test_run(suite="theme_factory")`.
Expected: PASS, including both new tests.

- [ ] **Step 8: Run the full suite**

**Controller action:** `test_run()`.
Expected: **309 passed, 1 failed** — the known `audio_director` bug only. The count rises from 307 because Task 1 added one test and this task added two.

- [ ] **Step 9: Confirm it on screen**

No automated test can judge whether the pill *looks* like the mockup, so check it directly.

**Controller action:** `project_run(mode="main")`, then via `game_eval`:

```gdscript
get_tree().change_scene_to_file("res://Scenes/StudentCard/student_card.tscn")
await get_tree().process_frame
await get_tree().process_frame
var sc = get_tree().current_scene
var layer = sc.get_node_or_null("TutorialCanvasLayer")
if layer:
	layer.visible = false
return "ok"
```

Then `editor_screenshot(source="game", max_resolution=1200)`.

Check four things against the mockup:
1. Both pills are **gold**, not olive or brown.
2. Each pill's **border is still dark purple**, not brown.
3. Pill text is **white, outlined, and noticeably larger** than before.
4. The info badges are **amber again** (Task 1's revert, visible on the same screen).

If the pill reads too dark, the `$vLo`/`$vHi` anchors in Step 3 are the knobs — raise `$deepR/G/B` toward `$goldR/G/B` to lift the bottom of the gradient, re-run Steps 3-4, and re-check. Do not reach for `modulate_color` to brighten it; that reintroduces the exact bug this task removes.

- [ ] **Step 10: Commit**

```bash
git add Assets/Images/StudentCard/trait_button.png Scripts/Design/ThemeFactory.gd Assets/Theme/kejartes_theme.tres tests/test_theme_factory.gd
git commit -m "feat(student-card): bake gold into the trait pill, outline its label"
```

---

## Self-Review

**Directive coverage.** Directive 1 ("undo the info icon colour") → Task 1. Directive 2 ("adjust the sifat pasif button to match the pic") → Task 2, covering both the fill colour and the text treatment the mockup shows.

**Deliberate non-delivery, flagged rather than silently dropped.** The mockup shows *green* info badges; Task 1 restores *amber* because that is what "undo" asked for. Task 1's body explains why the two cannot be reconciled with a tint and what closing the gap would actually take. If the intent was in fact "make the badge properly green," Task 1 is the wrong task and should be replaced with a new-asset task before execution.

**Type consistency.** `TraitPill` is the same variation name across `ThemeFactory.gd`, `test_theme_factory.gd`, `test_student_card.gd:135-136`, and `test_student_card_layout.gd:246` — none of those existing assertions change meaning. `trait_button.png` keeps its filename, so `test_student_card_layout.gd`'s `_EXPECTED_ART` list still resolves. `region_rect` and the 45px 9-slice margins are unchanged, so the recolour cannot shift the pill's geometry.

**Risks.**
1. *The recolour's saturation mask leaks into the border.* Step 4 samples both border pixels explicitly and fails the task if they moved — this is the single most important check in the plan.
2. *The larger font overflows a long trait name.* The longest real value is `Seni Dalam Kesunyian` (20 chars); at `font_h2` (48px) in Baloo2 that is roughly 480px inside ~750px of usable button width. Step 9's screenshot confirms it visually.
3. *The theme rebake is skipped.* `ThemeFactory.gd` alone changes nothing the game loads — `kejartes_theme.tres` is the artifact. Step 6 is the one step whose omission produces a silently unchanged UI, and Step 7 catches it because the new tests build the theme fresh rather than reading the baked file.
