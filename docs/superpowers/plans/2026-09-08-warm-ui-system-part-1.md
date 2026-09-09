# Warm UI System — Part 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace KejarTes' cold blue token palette with a warm Indonesian-school
one, give every button a single height-independent corner radius on an enforced
S/M/L size scale, fix two progress bars that currently fail contrast outright,
and relayout the lobby so the HUD stops covering students' faces.

**Architecture:** Everything cascades from `Assets/Theme/design_tokens.tres`.
Tokens change first, `ThemeFactory` consumes them, `BakeTheme` writes
`kejartes_theme.tres`, and scenes pick it up. Scene work happens last and
separately from script work. Two new tests convert the size scale from a written
convention into something the suite enforces.

**Tech Stack:** Godot 4.6 (mobile renderer, Vulkan), GDScript, the `godot-ai`
MCP bridge for driving the live editor, `McpTestSuite` for tests.

**Spec:** `docs/superpowers/specs/2026-09-08-warm-ui-system-design.md`

## Global Constraints

- **Godot 4.6**, portrait design space **1080×1920**. All coordinates in this
  plan are in that space.
- **Every test suite must be `@tool extends McpTestSuite`** with a
  `suite_name()`. A suite that is not `@tool` reports as abstract/broken.
- **No test may be a coroutine.** The runner calls `suite.call(name)` without
  awaiting; a single `await` silently aborts the test and it reports "0
  assertions".
- **Never add a `theme_override_*`.** Use a `ThemeFactory` type variation. The
  only accepted exception is layout-only constants (`separation`, `margin_*`).
- **No visual is built at runtime.** Static chrome is a node in the `.tscn`.
- **Every script needs a `##` file header and a `##` line on every `@export`** —
  `tests/test_script_documentation.gd` enforces this and will fail the suite.
- **Game-facing identifiers and all UI text are Indonesian**; engine and systems
  code is English.
- **No emoji as UI iconography.** Use real transparent PNG/SVG textures.
- **`Scripts/Balance.gd` is owned by a collaborator. Read it, never edit it.**
- **Rescan after editing a `.gd`, before running tests** — `test_run` serves a
  stale autoload otherwise. If the `.gd` was written from outside the editor, a
  no-op `script_patch` on that same file is required to force the reload.
- **Never hand-edit a `.tscn` while the editor is attached.** Go through
  `scene_open` → `node_create`/`node_set_property` → `scene_save`.
- **Do scene work after script work.** `scene_save` flushes the editor's stale
  `.gd` buffers over anything patched. After any `scene_save`, check
  `git diff HEAD -- '*.gd'` for files you were not editing.
- **The Godot MCP bridge is single-client.** Do not delegate editor work to a
  subagent; a subagent that connects displaces this session and both then fail.
- Tunable numbers belong in a named `const` block or an `@export`, never inline.

---

## File Structure

| File | Responsibility | Action |
|---|---|---|
| `Scripts/Design/DesignTokens.gd` | every visual constant; 16 new exports | Modify |
| `Assets/Theme/design_tokens.tres` | the resource instance | Modify (via editor) |
| `Scripts/Design/ThemeFactory.gd` | builds the Theme from tokens | Modify |
| `tests/test_theme_rebake.gd` | headless rebake utility | **Create** |
| `tests/test_button_geometry.gd` | radius, natural height, height ratchet | **Create** |
| `tests/test_bar_contrast.gd` | WCAG guard on every on-dark accent | **Create** |
| `tests/test_lobby_layout.gd` | nav tile baseline, rim clearance | **Create** |
| `tests/test_design_tokens.gd` | 3 hex assertions | Modify |
| `tests/test_day_summary.gd` | 8 hex assertions | Modify |
| `tests/test_theme_factory.gd` | `DISPLAY_ROSTER` | Modify |
| `Scenes/Lobby/loby.tscn` | HUD + nav relayout | Modify (editor only) |
| `Assets/Images/UI/Nav/*.png` | 5 nav icons | **Create** |
| `Assets/Images/StudentCard/menu_button.png` | 20px-corner menu art | **Create** |

Four new test files rather than one: `test_button_geometry.gd` is about
geometry, `test_bar_contrast.gd` about colour, `test_lobby_layout.gd` about one
scene, and `test_theme_rebake.gd` is a build utility, not a test of behaviour.
Bundling them would make the failure message tell you less than the file name.

---

## Task 1: Token values and the 16 new exports

**Files:**
- Modify: `tests/test_design_tokens.gd:13-16`
- Modify: `tests/test_day_summary.gd:100-118`
- Modify: `Scripts/Design/DesignTokens.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: `DesignTokens.radius_button: int`, `btn_h_s/m/l: int`,
  `btn_icon_s/m/l: int`, `btn_pad_v_s/m/l: int`,
  `cat_<name>_on_dark: Color` for the six categories, and
  `DesignTokens.category_color_on_dark(category: String) -> Color`.

- [ ] **Step 1: Update the hex assertions to the new expected values**

In `tests/test_design_tokens.gd`, replace the body of
`test_brand_palette_matches_approved_values`:

```gdscript
func test_brand_palette_matches_approved_values() -> void:
	var tokens := DesignTokens.load_default()
	assert_eq(tokens.brand_primary.to_html(false), "7a4a2b", "brand_primary")
	assert_eq(tokens.surface_card.to_html(false), "fffdf8", "surface_card")
	assert_eq(tokens.text_primary.to_html(false), "3b2412", "text_primary")
```

In `tests/test_day_summary.gd`, replace the `expected` dict inside
`test_day_summary_tokens_match_the_mockup`:

```gdscript
	var expected := {
		"day_avatar_fill": "7a4a2b",
		"day_avatar_border": "fff6e8",
		"day_bar_track": "4a3728",
		"day_bar_border": "2e2118",
		"day_energy_fill": "a78bfa",
		"day_mood_fill": "f5a623",
		"day_stat_track": "3f2e21",
		"day_glyph_outline": "2e2118",
	}
```

Also update that test's doc comment — it currently claims every colour was
centroid-sampled from a mockup, which stops being true here:

```gdscript
## These were sampled from the grey mockup until 2026-09-08, when the
## warm-UI pass replaced them. They are now design values, not samples:
## the dark greys measured 1.36:1 (energy) and 2.55:1 (olahraga) against
## their fills, which is unreadable. See test_bar_contrast.gd, which is
## now the test that actually constrains them.
```

- [ ] **Step 2: Run the two suites to verify they fail**

```
test_run(suite="design_tokens")
test_run(suite="day_summary")
```

Expected: FAIL. `design_tokens` reports `brand_primary` expected `7a4a2b` got
`2e5bff`. `day_summary` reports `token day_bar_track drifted from the mockup
sample`.

- [ ] **Step 3: Change the token values in `DesignTokens.gd`**

Apply exactly these. Do not adjust any value; each on-dark accent was chosen to
clear a measured contrast floor and changing one silently breaks Task 6.

```gdscript
@export var brand_primary: Color = Color("7A4A2B")
@export var brand_primary_light: Color = Color("9C6440")
@export var brand_primary_dark: Color = Color("56321B")

@export var surface_page: Color = Color("FBF1E3")
@export var surface_card: Color = Color("FFFDF8")
@export var surface_sunken: Color = Color("EFE0CB")
@export var surface_overlay: Color = Color("2E2118")

@export var outline_card: Color = Color("FFF6E8")
@export var shadow_color: Color = Color(0.23, 0.14, 0.06, 0.30)
@export var shadow_size: int = 12

@export var text_primary: Color = Color("3B2412")
@export var text_secondary: Color = Color("7A5C40")
@export var text_on_brand: Color = Color("FFF6E8")
@export var text_disabled: Color = Color("BFA88C")
@export var text_outline_color: Color = Color("FFF6E8")

@export var cat_akademis: Color = Color("2E86D8")
@export var cat_olahraga: Color = Color("E03A18")
@export var cat_senibudaya: Color = Color("4FA317")
@export var cat_istirahat: Color = Color("7C3AED")
@export var cat_libur: Color = Color("D98E0B")
@export var cat_wirausaha: Color = Color("0E9E7A")

@export var state_success: Color = Color("35A05A")
@export var state_warning: Color = Color("F5A623")
@export var state_danger: Color = Color("C0392B")

@export var day_avatar_fill: Color = Color("7A4A2B")
@export var day_avatar_border: Color = Color("FFF6E8")
@export var day_bar_track: Color = Color("4A3728")
@export var day_bar_border: Color = Color("2E2118")
@export var day_stat_track: Color = Color("3F2E21")
@export var day_glyph_outline: Color = Color("2E2118")
@export var day_energy_fill: Color = Color("A78BFA")
@export var day_mood_fill: Color = Color("F5A623")

@export var preview_row_fill: Color = Color("6B4B33")
@export var preview_row_border: Color = Color("2E2118")
@export var preview_pill_fill: Color = Color("4A3728")
```

**`currency_gold` stays `Color("ffc93c")` — do not touch it.** It is the colour
of `trait_button.png`, the asset that prompted this pass. `cat_libur` moved to
`D98E0B` specifically so the two stop colliding; changing `currency_gold`
instead re-creates the collision from the other side.

- [ ] **Step 4: Add the 16 new exports, each with its `##` doc line**

Append to the `Category Accents` group:

```gdscript
## Akademis on a DARK ground. The light-track cat_akademis measures only
## 1.93:1 against day_bar_track and is unreadable there; this is the value
## the DaySummary card uses. Guarded by tests/test_bar_contrast.gd.
@export var cat_akademis_on_dark: Color = Color("3BA7F5")
## Olahraga on a dark ground. See cat_akademis_on_dark.
@export var cat_olahraga_on_dark: Color = Color("FF5A36")
## SeniBudaya on a dark ground. See cat_akademis_on_dark.
@export var cat_senibudaya_on_dark: Color = Color("6BD425")
## Istirahat on a dark ground, also the DaySummary energy fill's family.
@export var cat_istirahat_on_dark: Color = Color("A78BFA")
## Libur on a dark ground, also the DaySummary mood fill's family.
@export var cat_libur_on_dark: Color = Color("F5A623")
## Wirausaha on a dark ground. See cat_akademis_on_dark.
@export var cat_wirausaha_on_dark: Color = Color("16C79A")
```

Add to the `Radii` group:

```gdscript
## Corner radius for every Button that reads as a button. Fixed in pixels
## on purpose: radius_pill clamps to half the box height, so before
## 2026-09-08 the project's 15 authored button heights produced 15
## different corner radii between 31 and 145 px. Chips and cards opt out
## explicitly -- see ThemeFactory's radius table.
@export var radius_button: int = 20
```

Add a new group after `Spacing`:

```gdscript
@export_group("Button Scale")
## Small step: the most common authored height, and equal to
## touch_target_min. Font is font_title.
@export var btn_h_s: int = 96
## Medium step. Font is font_h2.
@export var btn_h_m: int = 128
## Large step. Font is font_h1.
@export var btn_h_l: int = 160
## Icon edge length inside a small button.
@export var btn_icon_s: int = 48
## Icon edge length inside a medium button.
@export var btn_icon_m: int = 64
## Icon edge length inside a large button.
@export var btn_icon_l: int = 80
## Vertical content_margin for the small step. SOLVED, not chosen: it is
## tuned so a small button's NATURAL minimum height equals btn_h_s, which
## is what lets scene authors set no height at all and never land between
## steps. Re-solve with Task 5's probe if the display font changes.
@export var btn_pad_v_s: int = 20
## Vertical content_margin for the medium step. See btn_pad_v_s.
@export var btn_pad_v_m: int = 29
## Vertical content_margin for the large step. See btn_pad_v_s.
@export var btn_pad_v_l: int = 35
```

> The three `btn_pad_v_*` values above are **placeholders derived from an
> estimated font line box**. Task 5 measures Boohong in-engine and replaces
> them. Do not treat them as correct.

- [ ] **Step 5: Add `category_color_on_dark()`**

Directly below the existing `category_color()`:

```gdscript
## Resolve a schedule category to its accent for use on a DARK ground.
## Same shape and same fallback as category_color(); the two exist as a
## pair because one colour cannot clear contrast on both the light
## StatBar track and the dark DaySummary track.
func category_color_on_dark(category: String) -> Color:
	match category:
		"Akademis", "Akademik": return cat_akademis_on_dark
		"Olahraga": return cat_olahraga_on_dark
		"SeniBudaya", "Seni Budaya": return cat_senibudaya_on_dark
		"Istirahat": return cat_istirahat_on_dark
		"Libur": return cat_libur_on_dark
		"Wirausaha": return cat_wirausaha_on_dark
		_: return text_secondary
```

- [ ] **Step 6: Rescan, then run both suites to verify they pass**

```
filesystem_manage(op="scan")
test_run(suite="design_tokens")
test_run(suite="day_summary")
```

Expected: PASS. If `design_tokens` still reports the old hex, the editor is
serving stale bytecode — apply a no-op `script_patch` to `DesignTokens.gd`
(add and remove a blank line) and re-run. A benign
`GDScript reload failed with error code 43` in the log is expected and fine.

- [ ] **Step 7: Commit**

```bash
git add Scripts/Design/DesignTokens.gd tests/test_design_tokens.gd tests/test_day_summary.gd
git commit -m "feat(tokens): warm the palette and add the button-scale exports

Replaces the cold blue chrome with a warm Indonesian-school palette and
adds 16 exports: six on-dark category accents, radius_button, and the
S/M/L height, icon and padding scale.

The on-dark accents exist because one colour cannot clear contrast on
both grounds -- Seni measures 1.29:1 on a light track, Akademis 1.93:1,
while the old dark greys gave energy 1.36:1 and Olahraga 2.55:1.

btn_pad_v_s/m/l are placeholders; Task 5 solves them by measurement."
```

---

## Task 2: Editor restart, first rebake, and the rebake utility

**This is a hard checkpoint. The game renders incorrectly from Task 1 step 3
until this task completes. Do not split Tasks 1–6 across sessions.**

**Files:**
- Create: `tests/test_theme_rebake.gd`

**Interfaces:**
- Consumes: Task 1's new exports.
- Produces: a `theme_rebake` suite that regenerates
  `Assets/Theme/kejartes_theme.tres` headlessly, so later tasks never need
  File > Run.

- [ ] **Step 1: Restart the Godot editor**

A new `@export` on a `Resource` is invisible to a running editor — the cached
`DesignTokens` script has no knowledge of `radius_button` or the on-dark
accents, and any `ThemeFactory` read of them errors. There is no headless path
around this.

Restarting also reclaims the memory this build leaks, which has dropped the MCP
connection twice in one session before.

- [ ] **Step 2: Reopen the main scene and confirm the bridge**

```
scene_open(path="res://Scenes/MainMenu/main_menu.tscn")
editor_state()
```

Several suites assume the main scene is open and return a `scene_warning`
otherwise. Do not trust any failure reported before this step.

- [ ] **Step 3: Verify the new exports are visible**

```
test_run(suite="design_tokens")
```

Expected: PASS. If it errors on an unknown property, the restart did not take —
restart again before continuing. Everything downstream depends on this.

- [ ] **Step 4: Create the headless rebake utility**

Create `tests/test_theme_rebake.gd`:

```gdscript
@tool
extends McpTestSuite

## Regenerates Assets/Theme/kejartes_theme.tres, headlessly.
##
## Scripts/Design/BakeTheme.gd is an EditorScript, and there is no MCP
## entry point for one -- it needs File > Run by hand. This suite does the
## same build-and-save through test_run instead, which is the only way an
## agent-driven session can rebake at all.
##
## It is a build utility wearing a test's clothes. It asserts only that
## the save succeeded, because that is the only thing about it that can
## fail. Run it after ANY change to DesignTokens.gd or ThemeFactory.gd.

const OUTPUT_PATH := "res://Assets/Theme/kejartes_theme.tres"


func suite_name() -> String:
	return "theme_rebake"


func test_rebake_writes_the_theme() -> void:
	var tokens := DesignTokens.load_default()
	assert_not_null(tokens, "design_tokens.tres failed to load")

	var theme := ThemeFactory.build(tokens)
	assert_not_null(theme, "ThemeFactory.build returned null")

	var err := ResourceSaver.save(theme, OUTPUT_PATH)
	assert_eq(err, OK, "ResourceSaver.save failed with error %d" % err)

	print("theme_rebake: wrote ", OUTPUT_PATH, " (",
		theme.get_type_list().size(), " types)")
```

- [ ] **Step 5: Rebake and confirm the whole suite is green**

```
filesystem_manage(op="scan")
test_run(suite="theme_rebake")
test_run()
```

Expected: `theme_rebake` PASSes and prints the type count. The full run should
be green. If `test_baked_theme_matches_what_the_factory_builds` fails, the bake
did not land — re-run `theme_rebake` and scan again.

- [ ] **Step 6: Commit**

```bash
git add tests/test_theme_rebake.gd Assets/Theme/kejartes_theme.tres
git commit -m "feat(design): add a headless theme rebake path

BakeTheme.gd is an EditorScript with no MCP entry point, so an
agent-driven session could not rebake at all. This suite does the same
ThemeFactory.build + ResourceSaver.save through test_run.

Also carries the first bake of the warm palette."
```

---

## Task 3: `_button_box()`, the radius parameter, and the four bypassers

**Files:**
- Create: `tests/test_button_geometry.gd`
- Modify: `Scripts/Design/ThemeFactory.gd:272-300` (`_pill`)
- Modify: `Scripts/Design/ThemeFactory.gd:236-270` (`_add_button_variation`)
- Modify: `Scripts/Design/ThemeFactory.gd:143-176` (`_build_shop_shelf_button`)
- Modify: `Scripts/Design/ThemeFactory.gd:38-56` (`_add_shop_hub_tile`)
- Modify: `Scripts/Design/ThemeFactory.gd:884-901` (`WeekTabButton`)

**Interfaces:**
- Consumes: `tokens.radius_button`, `tokens.btn_pad_v_s`.
- Produces: `ThemeFactory._button_box(tokens, top, bottom, border, shadow_dy, radius) -> StyleBoxFlat`
  and `_add_button_variation(theme, tokens, name, top, bottom, border, text_color, radius := -1)`.
  A `radius` of `-1` means "use `tokens.radius_button`".

- [ ] **Step 1: Write the failing radius test**

Create `tests/test_button_geometry.gd`:

```gdscript
@tool
extends McpTestSuite

## Guards the button geometry system introduced 2026-09-08.
##
## Before that pass every button variation used radius_pill (999), which
## Godot clamps to half the box height -- so the project's 15 authored
## button heights rendered as 15 different corner radii between 31 and
## 145 px from one nominal style. These tests exist so that cannot
## silently return.

func suite_name() -> String:
	return "button_geometry"

var _tokens: DesignTokens
var _theme: Theme


func setup() -> void:
	_tokens = DesignTokens.load_default()
	_theme = ThemeFactory.build(_tokens)


## Variations that are Button-based but deliberately do NOT use
## radius_button. Every entry needs a reason -- an unreasoned entry is
## how the old inconsistency justified itself.
const RADIUS_EXEMPT := {
	"MainMenuButton":
		"StyleBoxTexture -- the gold gloss is painted, so the corner lives in menu_button.png",
	"TraitPill":
		"chip, StyleBoxTexture, stays fully round so it reads as a label not a control",
	"QuirkBadge":
		"chip -- stays radius_pill by design",
	"PersonaBadge":
		"chip -- stays radius_pill by design",
	"EventSelectCard":
		"reads as a card, not a button -- radius_lg",
}


## Collect every type whose variation base is Button.
func _button_variations() -> Array:
	var out := []
	for name in _theme.get_type_list():
		if _theme.get_type_variation_base(name) == &"Button":
			out.append(name)
	return out


func test_every_button_variation_uses_one_fixed_radius() -> void:
	var checked := 0
	for name in _button_variations():
		if RADIUS_EXEMPT.has(name):
			continue
		# ShopHubTile's normal is StyleBoxEmpty by design; its washes
		# carry the shape, so fall through to hover.
		var sb := _theme.get_stylebox("normal", name) as StyleBoxFlat
		if sb == null:
			sb = _theme.get_stylebox("hover", name) as StyleBoxFlat
		if sb == null:
			continue
		checked += 1
		assert_eq(sb.corner_radius_top_left, _tokens.radius_button,
			"%s must use radius_button (%d), got %d"
				% [name, _tokens.radius_button, sb.corner_radius_top_left])
	assert_true(checked >= 8,
		"expected to check at least 8 button variations, checked %d -- "
		% checked + "the collector is probably not finding them")


func test_exempt_variations_still_exist() -> void:
	# An exemption for a variation that no longer exists is dead weight
	# that hides the next real one.
	var all := _theme.get_type_list()
	for name in RADIUS_EXEMPT:
		assert_true(all.has(name),
			"%s is exempt from the radius rule but no longer exists" % name)
```

- [ ] **Step 2: Run it to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="button_geometry")
```

Expected: FAIL, many lines. `PrimaryButton must use radius_button (20), got
999`, plus `ShopShelfButton ... got 24` and `WeekTabButton ... got 24`.

- [ ] **Step 3: Rename `_pill` to `_button_box` and take a radius**

Replace the whole `_pill` function. Note the doc comment loses its "Umamusume
sheen" framing — the warm system's affordance is the bevel and shadow, and
leaving the old wording would misdescribe what the code now does.

```gdscript
## One button surface in four states.
##
## `radius` is explicit rather than always tokens.radius_button because
## chips (QuirkBadge, PersonaBadge) and cards (EventSelectCard) are built
## through this same path and must opt out. See the table in
## _build_buttons.
##
## `top`/`bottom` are kept as separate parameters even though
## StyleBoxFlat has no gradient: the two-tone read comes from a lighter
## fill plus the darker bottom border acting as a bevel, and the pressed
## state flips them.
static func _button_box(
	tokens: DesignTokens,
	top: Color,
	bottom: Color,
	border: Color,
	shadow_dy: float,
	radius: int
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = top
	sb.border_color = border
	sb.border_width_left = int(tokens.outline_width)
	sb.border_width_top = int(tokens.outline_width)
	sb.border_width_right = int(tokens.outline_width)
	sb.border_width_bottom = int(tokens.outline_width)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = tokens.shadow_color
	sb.shadow_size = tokens.shadow_size
	sb.shadow_offset = Vector2(tokens.shadow_offset.x,
		tokens.shadow_offset.y + shadow_dy)
	sb.content_margin_left = tokens.space_lg
	sb.content_margin_right = tokens.space_lg
	sb.content_margin_top = tokens.btn_pad_v_s
	sb.content_margin_bottom = tokens.btn_pad_v_s
	return sb
```

- [ ] **Step 4: Give `_add_button_variation` a radius parameter**

Replace its signature and the five `_pill` call sites inside it:

```gdscript
static func _add_button_variation(
	theme: Theme,
	tokens: DesignTokens,
	name: String,
	top: Color,
	bottom: Color,
	border: Color,
	text_color: Color,
	radius: int = -1
) -> void:
	# -1 means "the default", resolved here so callers that do not care
	# about shape do not have to name the token.
	var r: int = tokens.radius_button if radius < 0 else radius

	theme.add_type(name)
	theme.set_type_variation(name, "Button")

	theme.set_stylebox("normal", name,
		_button_box(tokens, top, bottom, border, 0.0, r))
	theme.set_stylebox("hover", name,
		_button_box(tokens, top.lightened(0.08), bottom.lightened(0.08), border, 0.0, r))
	theme.set_stylebox("pressed", name,
		_button_box(tokens, bottom, top, border, -tokens.shadow_offset.y * 0.5, r))
	theme.set_stylebox("focus", name,
		_button_box(tokens, top, bottom, tokens.brand_primary, 0.0, r))

	var disabled := _button_box(tokens,
		top.lerp(tokens.surface_sunken, 0.7),
		bottom.lerp(tokens.surface_sunken, 0.7),
		border.lerp(tokens.surface_sunken, 0.5), 0.0, r)
	disabled.shadow_size = 0
	theme.set_stylebox("disabled", name, disabled)

	theme.set_color("font_color", name, text_color)
	theme.set_color("font_hover_color", name, text_color)
	theme.set_color("font_pressed_color", name, text_color)
	theme.set_color("font_focus_color", name, text_color)
	theme.set_color("font_disabled_color", name, tokens.text_disabled)
	theme.set_font_size("font_size", name, tokens.font_title)
	if tokens.font_display != null:
		theme.set_font("font", name, tokens.font_display)
```

- [ ] **Step 5: Opt the chips and the card out, in `_build_buttons`**

Change three existing calls to pass an explicit radius:

```gdscript
	_add_button_variation(theme, tokens, "EventSelectCard",
		tokens.surface_card, tokens.surface_card,
		tokens.brand_primary, tokens.text_primary,
		tokens.radius_lg)

	_add_button_variation(theme, tokens, "QuirkBadge",
		tokens.brand_primary_light, tokens.brand_primary_dark,
		tokens.outline_card, tokens.text_on_brand,
		tokens.radius_pill)

	_add_button_variation(theme, tokens, "PersonaBadge",
		tokens.cat_istirahat.lightened(0.18), tokens.cat_istirahat.darkened(0.24),
		tokens.outline_card, tokens.text_on_brand,
		tokens.radius_pill)
```

Add a comment above them recording why the parameter exists at all:

```gdscript
	# The radius argument is what makes "chips stay round" implementable.
	# QuirkBadge and PersonaBadge are chips but are built through
	# _add_button_variation, so without it they would be forced to
	# radius_button along with everything else.
```

- [ ] **Step 6: Bring the three bypassers onto `radius_button`**

In `_build_shop_shelf_button`, change one line:

```gdscript
	normal.set_corner_radius_all(tokens.radius_button)
```

In `_add_shop_hub_tile`, change both wash styleboxes:

```gdscript
	wash.set_corner_radius_all(tokens.radius_button)
```
```gdscript
	pressed.set_corner_radius_all(tokens.radius_button)
```

In the `WeekTabButton` block, change the two top corners and leave the bottom
square — it is a tab, and a tab's bottom edge meets its panel:

```gdscript
	tab_normal.corner_radius_top_left = tokens.radius_button
	tab_normal.corner_radius_top_right = tokens.radius_button
```

- [ ] **Step 7: Rebake and verify the test passes**

```
filesystem_manage(op="scan")
test_run(suite="theme_rebake")
test_run(suite="button_geometry")
```

Expected: PASS, with at least 8 variations checked.

- [ ] **Step 8: Run the full suite**

```
test_run()
```

Expected: green. `test_theme_factory` may fail if it asserts a pill radius
anywhere — if so, that assertion is now describing the defect this task
removed, so update it to `radius_button` rather than reverting the change.

- [ ] **Step 9: Commit**

```bash
git add Scripts/Design/ThemeFactory.gd tests/test_button_geometry.gd Assets/Theme/kejartes_theme.tres
git commit -m "feat(theme): one fixed button radius, replacing radius_pill

_pill becomes _button_box and takes an explicit radius. That parameter
is load-bearing rather than cosmetic: QuirkBadge and PersonaBadge are
chips that must stay round, but they are built through
_add_button_variation, so without it the chips-stay-round rule is
unimplementable.

Also brings the three hand-built Button variations that never touched
_pill onto the same radius -- ShopShelfButton, ShopHubTile's washes and
WeekTabButton's top corners. MainMenuButton stays exempt with its reason
recorded; its corner lives in the art."
```

---

## Task 4: The M and L size-step variations

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd` (`_build_buttons`)
- Modify: `tests/test_theme_factory.gd:302-313` (`DISPLAY_ROSTER`)

**Interfaces:**
- Consumes: Task 3's `_add_button_variation` signature.
- Produces: theme types `PrimaryButtonM`, `SecondaryButtonM`, `DangerButtonM`,
  `PrimaryButtonL`, `SecondaryButtonL`, `DangerButtonL`, `SuccessButtonL`.

- [ ] **Step 1: Add the seven siblings to the geometry test**

Append to `tests/test_button_geometry.gd`:

```gdscript
## Godot type variations do not compose -- "PrimaryButton, but L" is not
## expressible -- so each role that has a non-S call site needs its own
## sibling. These seven cover the heights actually authored in the
## project; combinations nothing uses are deliberately not generated.
const SIZE_STEPS := {
	"PrimaryButton": "s", "SecondaryButton": "s",
	"DangerButton": "s", "SuccessButton": "s",
	"PrimaryButtonM": "m", "SecondaryButtonM": "m", "DangerButtonM": "m",
	"PrimaryButtonL": "l", "SecondaryButtonL": "l",
	"DangerButtonL": "l", "SuccessButtonL": "l",
}


func test_every_size_step_variation_exists() -> void:
	var all := _theme.get_type_list()
	for name in SIZE_STEPS:
		assert_true(all.has(name), "theme must declare type: " + name)


func test_size_steps_carry_the_right_font_size() -> void:
	var expected := {
		"s": _tokens.font_title,
		"m": _tokens.font_h2,
		"l": _tokens.font_h1,
	}
	for name in SIZE_STEPS:
		var step: String = SIZE_STEPS[name]
		assert_eq(_theme.get_font_size("font_size", name), expected[step],
			"%s is the %s step and must use font size %d"
				% [name, step.to_upper(), expected[step]])
```

- [ ] **Step 2: Run it to verify it fails**

```
test_run(suite="button_geometry")
```

Expected: FAIL — `theme must declare type: PrimaryButtonM`.

- [ ] **Step 3: Build the seven siblings**

Add a helper next to `_add_button_variation`, then call it. The helper exists so
a size step is one line rather than a duplicated seven-argument call:

```gdscript
## Clone an existing role variation at a larger size step.
##
## Only font_size differs -- the fill, rim and radius are the role's, so
## a PrimaryButtonL is unmistakably a PrimaryButton. Height comes from
## the step's own vertical padding, which is why this also re-pads.
static func _add_size_step(
	theme: Theme,
	tokens: DesignTokens,
	base: String,
	suffix: String,
	font_size: int,
	pad_v: int
) -> void:
	var name := base + suffix
	theme.add_type(name)
	theme.set_type_variation(name, "Button")

	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := (theme.get_stylebox(state, base) as StyleBoxFlat).duplicate()
		sb.content_margin_top = pad_v
		sb.content_margin_bottom = pad_v
		theme.set_stylebox(state, name, sb)

	for key in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color", "font_disabled_color"]:
		theme.set_color(key, name, theme.get_color(key, base))

	theme.set_font_size("font_size", name, font_size)
	if tokens.font_display != null:
		theme.set_font("font", name, tokens.font_display)
```

Call it at the end of `_build_buttons`, after every base role exists:

```gdscript
	# Size steps. M covers the 116-148 px call sites (TesNotice, RunResult,
	# QuitConfirmDialog, EndCutscene, AturJadwal's StartWeek); L covers the
	# 160-178 px ones (StudentCard's Aprove and Batal, StudentList's
	# arrows). SuccessButton has no M call site, so none is generated.
	for base in ["PrimaryButton", "SecondaryButton", "DangerButton"]:
		_add_size_step(theme, tokens, base, "M", tokens.font_h2, tokens.btn_pad_v_m)
	for base in ["PrimaryButton", "SecondaryButton", "DangerButton", "SuccessButton"]:
		_add_size_step(theme, tokens, base, "L", tokens.font_h1, tokens.btn_pad_v_l)
```

- [ ] **Step 4: Update `DISPLAY_ROSTER`**

In `tests/test_theme_factory.gd`, add the seven and **remove
`"LobbyNavButton"`**. That removal is not optional — Task 11 retires the
variation, and a roster entry for a type that no longer exists fails the
"roster name has the display font" assertion.

```gdscript
const DISPLAY_ROSTER := [
	"DisplayLabel", "H1Label", "H2Label", "TitleLabel",
	"CardSectionLabel", "ResultHeroLabel",
	"MainMenuButton", "PrimaryButton", "SecondaryButton", "DangerButton",
	"SuccessButton", "QuirkBadge", "PersonaBadge",
	"EventSelectCard", "ShopHubTileLabel", "FilterChipButton",
	"TraitPill", "PreviewRowLabel",
	"DaySummaryName", "DaySummaryStat", "DaySummaryNeedsLabel",
	"RecapPillValueLabel", "ScoreHudValueLabel",
	# 2026-09-08: event popup title, display face at H1+6.
	"EventDialogHeaderLabel",
	# 2026-09-08 warm-UI pass: the M and L size steps. LobbyNavButton left
	# this roster in the same pass -- LobbyNavTile and LobbyCtaButton
	# replaced it.
	"PrimaryButtonM", "SecondaryButtonM", "DangerButtonM",
	"PrimaryButtonL", "SecondaryButtonL", "DangerButtonL", "SuccessButtonL",
	"LobbyNavTile", "LobbyCtaButton",
]
```

> `LobbyNavTile` and `LobbyCtaButton` are listed here but not built until
> Task 11. **The roster test will fail between this step and Task 11.** That is
> deliberate — it keeps the roster honest and makes Task 11 impossible to
> forget. If you need a green suite before then, add them in Task 11 as planned
> rather than removing them here.

- [ ] **Step 5: Rebake and verify**

```
filesystem_manage(op="scan")
test_run(suite="theme_rebake")
test_run(suite="button_geometry")
```

Expected: `button_geometry` PASSes. `theme_factory` fails on the two
not-yet-built lobby variations, as noted above.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Design/ThemeFactory.gd tests/test_theme_factory.gd tests/test_button_geometry.gd Assets/Theme/kejartes_theme.tres
git commit -m "feat(theme): add the M and L button size steps

Godot type variations do not compose, so each role with a non-S call
site needs an explicit sibling. Seven cover every height authored in the
project; combinations nothing uses are not generated.

DISPLAY_ROSTER gains the seven and loses LobbyNavButton, which Task 11
retires. It temporarily lists LobbyNavTile and LobbyCtaButton before
they exist, so the roster test stays red until that task lands."
```

---

## Task 5: Solve `btn_pad_v_s/m/l` by measurement

**This task's numbers cannot be written in advance.** They depend on Boohong's
real line box, which is why Task 1 shipped placeholders.

**Files:**
- Modify: `tests/test_button_geometry.gd`
- Modify: `Scripts/Design/DesignTokens.gd` (three values)

**Interfaces:**
- Consumes: Task 4's size-step variations.
- Produces: `btn_pad_v_s/m/l` solved so each step's natural minimum height
  equals its `btn_h_*` token.

- [ ] **Step 1: Write a probe that prints the real metrics**

Append to `tests/test_button_geometry.gd`:

```gdscript
## TEMPORARY probe -- delete in step 4. Prints what Godot actually
## reports so the padding can be solved rather than guessed.
func test_zz_probe_font_metrics() -> void:
	for spec in [["PrimaryButton", _tokens.btn_h_s],
			["PrimaryButtonM", _tokens.btn_h_m],
			["PrimaryButtonL", _tokens.btn_h_l]]:
		var name: String = spec[0]
		var sb := _theme.get_stylebox("normal", name) as StyleBoxFlat
		var font := _theme.get_font("font", name)
		var fsize := _theme.get_font_size("font_size", name)
		print("%s: target=%d  stylebox_min=%s  font_height=%f  pad=%d/%d  border=%d"
			% [name, spec[1], str(sb.get_minimum_size()),
				font.get_height(fsize),
				sb.content_margin_top, sb.content_margin_bottom,
				sb.border_width_top])
	assert_true(true, "probe only")
```

- [ ] **Step 2: Run it and read the numbers**

```
filesystem_manage(op="scan")
test_run(suite="button_geometry")
```

Read the three printed lines. What matters is whether
`stylebox_min.y` already includes the border, because that decides the formula.
Godot's `StyleBoxFlat.get_minimum_size()` returns the content margins when they
are set explicitly — confirm that against the printed `pad` and `border` values
rather than assuming it.

- [ ] **Step 3: Solve and write back the three values**

For each step, solve:

```
pad = (btn_h_<step> - font_height - border_contribution) / 2
```

using the `border_contribution` the probe showed (either `0` or
`2 * outline_width`). Round to the nearest integer; if a step lands on `.5`,
round **down** so the natural height never exceeds its token — a button that is
1px short is invisible, one that is 1px tall breaks the ratchet in Task 7.

Write the results into `DesignTokens.gd`, replacing the placeholders, and
update each doc line to record the measured font height:

```gdscript
## Vertical content_margin for the small step. SOLVED, not chosen: tuned
## so a small button's NATURAL minimum height equals btn_h_s (96), which
## is what lets scene authors set no height at all. Measured against
## Boohong at font_title: line box <MEASURED>px. Re-solve with
## test_button_geometry's probe if the display font changes.
@export var btn_pad_v_s: int = <SOLVED>
```

- [ ] **Step 4: Replace the probe with the real assertion**

Delete `test_zz_probe_font_metrics` entirely and add:

```gdscript
## The identity that makes the size scale self-enforcing.
##
## If a button's natural minimum height equals its step, a scene author
## sets no height at all and cannot land between steps. This asserts the
## identity rather than the padding numbers, so a font change fails here
## loudly instead of letting every button in the game drift a few pixels.
func test_natural_height_matches_the_size_step() -> void:
	var targets := {
		"PrimaryButton": _tokens.btn_h_s,
		"SecondaryButton": _tokens.btn_h_s,
		"DangerButton": _tokens.btn_h_s,
		"SuccessButton": _tokens.btn_h_s,
		"PrimaryButtonM": _tokens.btn_h_m,
		"SecondaryButtonM": _tokens.btn_h_m,
		"DangerButtonM": _tokens.btn_h_m,
		"PrimaryButtonL": _tokens.btn_h_l,
		"SecondaryButtonL": _tokens.btn_h_l,
		"DangerButtonL": _tokens.btn_h_l,
		"SuccessButtonL": _tokens.btn_h_l,
	}
	for name in targets:
		var sb := _theme.get_stylebox("normal", name) as StyleBoxFlat
		var font := _theme.get_font("font", name)
		var fsize := _theme.get_font_size("font_size", name)
		var natural: float = sb.get_minimum_size().y + font.get_height(fsize)
		assert_true(abs(natural - targets[name]) <= 1.0,
			"%s natural height is %f but its step is %d -- re-solve btn_pad_v"
				% [name, natural, targets[name]])
```

> If step 2 showed that `get_minimum_size()` does **not** include the border,
> add `+ sb.border_width_top + sb.border_width_bottom` to the `natural`
> expression here so the test and the derivation use the same formula.

- [ ] **Step 5: Rebake and verify**

```
filesystem_manage(op="scan")
test_run(suite="theme_rebake")
test_run(suite="button_geometry")
```

Expected: PASS on all eleven variations, within the 1px tolerance.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Design/DesignTokens.gd tests/test_button_geometry.gd Assets/Theme/kejartes_theme.tres
git commit -m "fix(tokens): solve btn_pad_v by measuring Boohong, not estimating

Each step's vertical padding is tuned so the variation's natural minimum
height equals its btn_h token. Scene authors then set no height at all
and cannot land between steps -- which is the whole reason the scale is
enforceable rather than advisory.

The test asserts the identity, not the numbers, so a font change fails
loudly instead of drifting every button a few pixels."
```

---

## Task 6: Contrast guard and the on-dark bar switch

**Files:**
- Create: `tests/test_bar_contrast.gd`
- Modify: `Scripts/Design/ThemeFactory.gd:795-805` (`bar_specs`)

**Interfaces:**
- Consumes: Task 1's `cat_*_on_dark` tokens.
- Produces: DaySummary stat tracks filled from the on-dark accents.

- [ ] **Step 1: Write the failing contrast test**

Create `tests/test_bar_contrast.gd`:

```gdscript
@tool
extends McpTestSuite

## WCAG contrast floor for every progress-bar fill against its track.
##
## This test exists because of a measured failure, not a hypothetical
## one. Before 2026-09-08 the DaySummary energy bar was #6d60c0 on a
## #585858 track -- 1.36:1, which is not a dim bar but an invisible one --
## and Olahraga was 2.55:1. Both shipped green for months because nothing
## checked.
##
## The floor is 3.0. The values chosen in the warm-UI pass all clear
## 3.5, so there is deliberate headroom for tuning.

const FLOOR := 3.0


func suite_name() -> String:
	return "bar_contrast"


## sRGB relative luminance, per WCAG 2.x. Godot's Color components are
## already sRGB-encoded 0..1, so they feed this directly.
static func _relative_luminance(c: Color) -> float:
	var out := 0.0
	var weights := [0.2126, 0.7152, 0.0722]
	var channels := [c.r, c.g, c.b]
	for i in 3:
		var v: float = channels[i]
		var lin: float = v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
		out += weights[i] * lin
	return out


static func _contrast(a: Color, b: Color) -> float:
	var la := _relative_luminance(a)
	var lb := _relative_luminance(b)
	var hi: float = max(la, lb)
	var lo: float = min(la, lb)
	return (hi + 0.05) / (lo + 0.05)


func test_every_on_dark_accent_clears_the_floor() -> void:
	var tokens := DesignTokens.load_default()
	assert_not_null(tokens, "design_tokens.tres failed to load")
	for category in ["Akademis", "Olahraga", "SeniBudaya",
			"Istirahat", "Libur", "Wirausaha"]:
		var fill := tokens.category_color_on_dark(category)
		var ratio := _contrast(fill, tokens.day_bar_track)
		assert_true(ratio >= FLOOR,
			"%s on-dark is %s against day_bar_track -- %.2f:1, floor is %.1f"
				% [category, fill.to_html(false), ratio, FLOOR])


func test_the_two_needs_fills_clear_the_floor() -> void:
	var tokens := DesignTokens.load_default()
	for spec in [["energy", tokens.day_energy_fill],
			["mood", tokens.day_mood_fill]]:
		var ratio := _contrast(spec[1], tokens.day_bar_track)
		assert_true(ratio >= FLOOR,
			"%s fill is %.2f:1 against day_bar_track, floor is %.1f"
				% [spec[0], ratio, FLOOR])


func test_light_track_accents_clear_the_floor_too() -> void:
	# The light StatBar track is the other half of the pair. If someone
	# "simplifies" by pointing both grounds at one token, this catches it.
	var tokens := DesignTokens.load_default()
	for category in ["Akademis", "Olahraga", "SeniBudaya",
			"Istirahat", "Libur", "Wirausaha"]:
		var fill := tokens.category_color(category)
		var ratio := _contrast(fill, tokens.surface_sunken)
		assert_true(ratio >= FLOOR,
			"%s on the light StatBar track is %.2f:1, floor is %.1f"
				% [category, ratio, FLOOR])


func test_libur_and_currency_gold_are_distinguishable() -> void:
	# They were the same yellow until 2026-09-08 -- #ffd333 and #ffc93c --
	# so a Libur bar and a coin count could not be told apart by hue.
	var tokens := DesignTokens.load_default()
	var d := absf(tokens.cat_libur.h - tokens.currency_gold.h) \
		+ absf(tokens.cat_libur.v - tokens.currency_gold.v)
	assert_true(d > 0.08,
		"cat_libur %s and currency_gold %s are too close in hue/value"
			% [tokens.cat_libur.to_html(false), tokens.currency_gold.to_html(false)])
```

- [ ] **Step 2: Run it to verify which assertions fail**

```
filesystem_manage(op="scan")
test_run(suite="bar_contrast")
```

Expected: the on-dark, needs and libur tests PASS immediately (Task 1 already
set those values). `test_light_track_accents_clear_the_floor_too` is the one
that may FAIL — the light-track accents were chosen by eye, not measured.

- [ ] **Step 3: If the light-track test fails, deepen the offenders**

Do **not** lower `FLOOR`. Darken only the failing `cat_*` values until each
clears 3.0 against `surface_sunken` `#EFE0CB`, keeping the hue. Record the new
value and its measured ratio in that token's `##` line. If a category cannot
clear 3.0 without losing its identity, stop and raise it — that is a design
decision, not an implementation one.

- [ ] **Step 4: Switch the DaySummary stat tracks to the on-dark accents**

In `ThemeFactory._build_day_summary`'s `bar_specs`:

```gdscript
	var bar_specs := [
		["DaySummaryEnergyBar", tokens.day_bar_track,
			tokens.day_energy_fill, tokens.day_bar_radius],
		["DaySummaryMoodBar", tokens.day_bar_track,
			tokens.day_mood_fill, tokens.day_bar_radius],
		["DaySummaryStatTrackAkademis", tokens.day_stat_track,
			tokens.cat_akademis_on_dark, tokens.radius_pill],
		["DaySummaryStatTrackSeniBudaya", tokens.day_stat_track,
			tokens.cat_senibudaya_on_dark, tokens.radius_pill],
		["DaySummaryStatTrackOlahraga", tokens.day_stat_track,
			tokens.cat_olahraga_on_dark, tokens.radius_pill],
	]
```

Note `radius_pill` stays here: these are `ProgressBar` variations, not
`Button`s, and a capsule bar is the intended shape.

- [ ] **Step 5: Rebake and run the full suite**

```
filesystem_manage(op="scan")
test_run(suite="theme_rebake")
test_run()
```

Expected: `bar_contrast` green. `theme_factory` still red on the two lobby
variations from Task 4.

- [ ] **Step 6: Commit**

```bash
git add tests/test_bar_contrast.gd Scripts/Design/ThemeFactory.gd Scripts/Design/DesignTokens.gd Assets/Theme/kejartes_theme.tres
git commit -m "feat(theme): guard bar contrast and use the on-dark accents

Adds a WCAG floor of 3.0:1 for every fill against its track, on both
grounds. This is the test that would have caught the energy bar at
1.36:1 and Olahraga at 2.55:1 -- both of which shipped green for months
because nothing measured them.

DaySummary's three stat tracks now draw from cat_*_on_dark."
```

---

## Task 7: The height ratchet

**Files:**
- Modify: `tests/test_button_geometry.gd`
- Modify: whichever scenes carry off-step heights (editor only)

**Interfaces:**
- Consumes: Task 5's solved padding.
- Produces: a ratchet that fails when a button is authored off-step.

- [ ] **Step 1: Write the ratchet**

Append to `tests/test_button_geometry.gd`:

```gdscript
## Every themed button in every scene must be authored at a size step.
##
## Fifteen ad-hoc heights is what accumulates when a scale is written
## down but not enforced -- 63, 80, 90, 94, 96, 116, 120, 135, 140, 144,
## 148, 160, 178, 267, 290 was the state on 2026-09-08. Without this the
## same drift starts again immediately.
##
## ALLOWED is for reviewed, commented exceptions and follows the same
## shape as test_viewport_editability.gd's dict. An entry needs a reason.
const HEIGHT_ALLOWED := {
	# "Scenes/Foo/bar.tscn::SomeButton": "why this one is off-step",
}

const SCENE_GLOB := "res://Scenes"


func _scene_files(dir_path: String, out: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path + "/" + entry
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_scene_files(full, out)
		elif entry.ends_with(".tscn"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()


func test_no_button_is_authored_off_step() -> void:
	var steps := [_tokens.btn_h_s, _tokens.btn_h_m, _tokens.btn_h_l]
	var scenes := []
	_scene_files(SCENE_GLOB, scenes)
	assert_true(scenes.size() > 20,
		"expected to find many scenes, found %d" % scenes.size())

	var offenders := []
	for path in scenes:
		var src := FileAccess.get_file_as_string(path)
		if src == "":
			continue
		# Minigames are out of the design system by standing policy.
		if path.contains("/Minigames/"):
			continue
		var node_name := ""
		var height := -1.0
		var top := INF
		for line in src.split("\n"):
			if line.begins_with("[node "):
				node_name = line.get_slice("name=\"", 1).get_slice("\"", 0)
				top = INF
				height = -1.0
			elif line.begins_with("offset_top = "):
				top = float(line.get_slice("= ", 1))
			elif line.begins_with("offset_bottom = ") and top != INF:
				height = float(line.get_slice("= ", 1)) - top
			elif line.begins_with("custom_minimum_size = Vector2("):
				height = float(line.get_slice(", ", 1).get_slice(")", 0))
			elif line.begins_with("theme_type_variation = &\"") \
					and line.contains("Button"):
				if height <= 0.0:
					continue
				var key := "%s::%s" % [path.replace("res://", ""), node_name]
				if HEIGHT_ALLOWED.has(key):
					continue
				if not steps.has(int(height)):
					offenders.append("%s = %d" % [key, int(height)])

	assert_eq(offenders.size(), 0,
		"buttons authored off the S/M/L scale:\n  " + "\n  ".join(offenders))
```

- [ ] **Step 2: Run it and capture the offender list**

```
filesystem_manage(op="scan")
test_run(suite="button_geometry")
```

Expected: FAIL, listing roughly 20 offenders. **Save that list** — it is the
work order for step 3. Known ones from the spec's survey: `ShopShelfButton`'s
`Rak1` at 63, `StudentCard`'s `Batal` at 178, `StudentList`'s `Belum`/`Sudah`
at 80, `AturJadwal`'s `ButtonYes`/`ButtonNo` at 90.

- [ ] **Step 3: Move each offender onto a step, in the editor**

For each, open the scene and set the height to the nearest step, using the
editor rather than a text edit:

```
scene_open(path="res://Scenes/StudentList/student_list.tscn")
node_set_property(path="Belum", property="offset_bottom", value=<top + 96>)
scene_save()
```

Rules for choosing:
- 63 → **96**. It is below `touch_target_min`; this is a tap-target fix as much
  as a visual one.
- 80, 90, 94 → **96**.
- 116, 120, 135, 140, 144, 148 → **128**.
- 160, 178 → **160**.
- 267, 290 (the lobby CTA) → **160**, handled in Task 11, so add a
  `HEIGHT_ALLOWED` entry now and remove it there:

```gdscript
const HEIGHT_ALLOWED := {
	"Scenes/Lobby/loby.tscn::Student":
		"lobby CTA -- relayout to L lands in Task 11, entry removed there",
	"Scenes/Lobby/loby.tscn::Jadwal":
		"lobby CTA -- relayout to L lands in Task 11, entry removed there",
}
```

After every `scene_save`, run `git diff HEAD -- '*.gd'` and confirm no script
changed. The editor flushes stale `.gd` buffers on save; if a script you were
not editing appears in that diff, revert it before continuing.

- [ ] **Step 4: Re-run until green**

```
test_run(suite="button_geometry")
```

Expected: PASS, with only the two lobby entries allow-listed.

- [ ] **Step 5: Commit**

```bash
git add tests/test_button_geometry.gd Scenes/
git commit -m "feat(theme): ratchet every button height onto the S/M/L scale

Fifteen ad-hoc heights is what accumulates when a scale is documented
but not enforced. This walks every themed button in every scene and
fails on anything off-step, with an ALLOWED dict in the same shape
test_viewport_editability.gd already uses.

Also moves the offenders onto a step, including ShopShelfButton's 63px
Rak1, which was under touch_target_min and so was a tap-target bug as
much as a visual one. The two lobby CTAs are allow-listed until their
relayout."
```

---

## Task 8: Generate the nav icons and the split menu art

**Files:**
- Create: `Assets/Images/UI/Nav/icon_nav_koperasi.png`
- Create: `Assets/Images/UI/Nav/icon_nav_inventory.png`
- Create: `Assets/Images/UI/Nav/icon_nav_rapor.png`
- Create: `Assets/Images/UI/Nav/icon_cta_jadwal.png`
- Create: `Assets/Images/UI/Nav/icon_cta_student.png`
- Create: `Assets/Images/StudentCard/menu_button.png`

**Interfaces:**
- Consumes: nothing.
- Produces: six textures, referenced by Tasks 9 and 11.

- [ ] **Step 1: Author the five nav icons**

256×256 transparent PNG each, flat silhouettes in `text_on_brand` `#FFF6E8`,
stroke weight matched to the existing `Assets/Images/UI/Placeholders/icon_*.svg`
set. Subjects: shopfront, satchel, report sheet, calendar, student.

These are **real art, not placeholders** — they go in `Assets/Images/UI/Nav/`,
not `Placeholders/`, and must not be added to the Outstanding debt list.

**No emoji.** These assets exist precisely so the tiles do not use glyphs.

- [ ] **Step 2: Author `menu_button.png`**

This is a **split, not an edit**. Do not modify `trait_button.png`.

`_build_main_menu_button`'s own doc comment records that it deliberately reuses
`TraitPill`'s `region_rect` and 45px margins because the menu mockup is that
asset recoloured — so one asset backs both the menu and every Quirk/Persona
chip. Redrawing it with a 20px corner would square off every chip in the game,
contradicting the chips-stay-round rule Task 3 just made enforceable.

Author `menu_button.png` as a **new** file: same gold `#FFC93C`, same `#3D2048`
rim, same top gloss as `trait_button.png`, but with a 20px corner radius.
Because it is a new canvas, `region_rect` and `texture_margin` must be
**re-derived** rather than copied from `Rect2(20, 277, 601, 91)` / margin 45 —
the whole point of the split is that the two shapes now differ.

Record the derived values; Task 9 needs them.

- [ ] **Step 3: Import and verify**

```
filesystem_manage(op="scan")
```

Confirm all six appear and none imported with a transparent-black fringe.

- [ ] **Step 4: Commit**

```bash
git add Assets/Images/UI/Nav/ Assets/Images/StudentCard/menu_button.png
git commit -m "feat(art): add five nav icons and split the menu button art

trait_button.png backs both MainMenuButton and TraitPill, so it cannot
be redrawn with a 20px corner without squaring off every Quirk and
Persona chip. menu_button.png is a new asset carrying that corner; the
original stays round for the chips."
```

---

## Task 9: Point `MainMenuButton` at the new art

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd:196-230` (`_build_main_menu_button`)

**Interfaces:**
- Consumes: Task 8's `menu_button.png` and its derived region/margin values.
- Produces: a `MainMenuButton` whose silhouette matches `radius_button`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_button_geometry.gd`:

```gdscript
## MainMenuButton is exempt from the radius rule because its corner is
## painted, not generated -- but "exempt" must not mean "unchecked". This
## asserts it points at the asset that carries the right corner, so the
## exemption cannot quietly become a way of keeping the old shape.
func test_main_menu_button_uses_the_split_asset() -> void:
	var sb := _theme.get_stylebox("normal", "MainMenuButton") as StyleBoxTexture
	assert_not_null(sb, "MainMenuButton/normal must be a StyleBoxTexture")
	assert_true(sb.texture != null, "MainMenuButton has no texture")
	assert_true(str(sb.texture.resource_path).ends_with("menu_button.png"),
		"MainMenuButton must use menu_button.png, not %s -- trait_button.png "
		% str(sb.texture.resource_path)
		+ "is the round chip art and must stay round")
```

- [ ] **Step 2: Run it to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="button_geometry")
```

Expected: FAIL — `MainMenuButton must use menu_button.png, not
res://Assets/Images/StudentCard/trait_button.png`.

- [ ] **Step 3: Repoint the variation**

In `_build_main_menu_button`, replace the texture load and the region/margin
lines with Task 8's derived values, and rewrite the doc comment — the existing
one describes the shared-asset arrangement that this change ends:

```gdscript
## The main menu's three nav buttons.
##
## Uses menu_button.png, NOT trait_button.png. The two were one asset
## until 2026-09-08: the menu mockup is the chip art recoloured, so
## reusing it reproduced the mockup exactly. That stopped working when
## buttons moved to a fixed 20px corner and chips stayed fully round --
## one asset cannot be both shapes. See the spec's "a split, not an edit".
##
## Still a StyleBoxTexture rather than a stylebox because the gold gloss
## is painted; the corner therefore lives in the art, which is why
## test_button_geometry allow-lists this variation and then checks the
## texture path instead.
```

```gdscript
	normal.texture = load(_CARD_ART + "menu_button.png")
	normal.region_rect = Rect2(<derived>, <derived>, <derived>, <derived>)
	normal.set_texture_margin_all(<derived>)
```

- [ ] **Step 4: Rebake and verify**

```
filesystem_manage(op="scan")
test_run(suite="theme_rebake")
test_run(suite="button_geometry")
```

Expected: PASS.

- [ ] **Step 5: Visually confirm the menu**

```
scene_open(path="res://Scenes/MainMenu/main_menu.tscn")
editor_screenshot()
```

Confirm PENGATURAN and KELUAR are not clipped and the corner reads as 20px.
The old 9-slice squeezed 45px margins into a 91px region; if the new margins are
too large for the new canvas the label will visibly pinch. This is the one place
in Part 1 where a screenshot is worth its cost — everything else is measurable.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Design/ThemeFactory.gd tests/test_button_geometry.gd Assets/Theme/kejartes_theme.tres
git commit -m "fix(mainmenu): point the menu buttons at the split art

Closes the last item from the original mentor review -- the splashscreen
Settings/Exit shape. The exemption from the radius rule stays, because
the gold gloss is painted, but it is no longer unchecked: a test asserts
the variation uses menu_button.png so the exemption cannot become a way
of keeping the old silhouette."
```

---

## Task 10: Re-anchor `DailyReward` — a prerequisite, not a follow-up

**Files:**
- Modify: `Scenes/Lobby/loby.tscn` (editor only)

**Interfaces:**
- Consumes: nothing.
- Produces: a `DailyReward` panel whose size is independent of `DailyLogin`.

- [ ] **Step 1: Confirm the coupling before touching it**

```
scene_open(path="res://Scenes/Lobby/loby.tscn")
node_get_properties(path="DailyLogin/DailyReward")
```

Expected: `anchor_right ≈ 5.994`, `anchor_bottom ≈ 2.915`. The panel's size is
**derived from its parent's** — at `DailyLogin`'s current 156px it resolves to
roughly 935px wide. Task 11 shrinks that button to 96px, which would drag the
popup to ~575px and break its seven-day row.

This is why the re-anchor comes first. Doing it after would mean debugging a
mangled popup while also changing the layout around it.

- [ ] **Step 2: Record the panel's current resolved rect**

```
game_manage(op="get_ui_elements",
            params={"root_path": "/root/Lobby/DailyLogin/DailyReward", "max_depth": 1})
```

Save the `global_rect`. That rect is the target: the popup must look identical
after the re-parent.

- [ ] **Step 3: Re-parent `DailyReward` to the scene root**

```
node_manage(op="reparent", path="DailyLogin/DailyReward", new_parent=".")
```

Then set absolute anchors and the offsets that reproduce the saved rect:

```
node_set_property(path="DailyReward", property="anchor_left", value=0)
node_set_property(path="DailyReward", property="anchor_top", value=0)
node_set_property(path="DailyReward", property="anchor_right", value=0)
node_set_property(path="DailyReward", property="anchor_bottom", value=0)
node_set_property(path="DailyReward", property="offset_left", value=<saved.x>)
node_set_property(path="DailyReward", property="offset_top", value=<saved.y>)
node_set_property(path="DailyReward", property="offset_right", value=<saved.x + saved.w>)
node_set_property(path="DailyReward", property="offset_bottom", value=<saved.y + saved.h>)
scene_save()
```

Numbers must be unquoted — `0`, not `"0.0"`.

- [ ] **Step 4: Fix the script's node paths**

`loby.gd:59-68` reaches the panel and its seven day slots through
`$DailyLogin/DailyReward`. Update all nine `@onready` paths to `$DailyReward/...`:

```gdscript
@onready var daily_reward = $DailyReward
@onready var claim_button = $DailyReward/ButtonClaim
```

and each of the seven entries in the day dictionary, e.g. `1: $DailyReward/Day1`.

Also check `loby.gd:586` — a comment there describes placing `blur_overlay`
"just before DailyLogin so it renders on top of other UI but behind the popup".
The popup is now a sibling of `DailyLogin`, so confirm the z-order still holds
and adjust the insertion index if not.

- [ ] **Step 5: Verify the popup is unchanged**

```
filesystem_manage(op="scan")
project_run()
```

Open the daily reward from the lobby. All seven day slots must be present and
the panel the same size as before. Compare against the rect saved in step 2.

- [ ] **Step 6: Commit**

```bash
git add Scenes/Lobby/loby.tscn Scripts/Lobby/loby.gd
git commit -m "fix(lobby): decouple the daily-reward panel from its button

DailyReward carried anchor_right 5.994 and anchor_bottom 2.915, so its
size was a multiple of DailyLogin's. Resizing that button for the HUD
relayout would have dragged the panel from ~935px wide down to ~575px
and broken its seven-day row.

Re-anchored to the scene root at the same resolved rect, with the nine
node paths in loby.gd updated to match."
```

---

## Task 11: Lobby HUD and nav relayout

**Files:**
- Create: `tests/test_lobby_layout.gd`
- Modify: `Scripts/Design/ThemeFactory.gd` (`LobbyNavTile`, `LobbyCtaButton`)
- Modify: `Scenes/Lobby/loby.tscn` (editor only)

**Interfaces:**
- Consumes: Task 8's icons, Task 10's re-anchored popup, Task 4's roster entries.
- Produces: theme types `LobbyNavTile` and `LobbyCtaButton`; retires
  `LobbyNavButton`.

- [ ] **Step 1: Write the failing layout test**

Create `tests/test_lobby_layout.gd`:

```gdscript
@tool
extends McpTestSuite

## Geometry guards for the lobby, from the 2026-09-08 warm-UI pass.
##
## Three defects motivated these, all measured rather than eyeballed:
## ReportStudent ended at x=1059 on a 1080-wide screen with a 6px border
## and a 14px shadow, so it clipped; DisplayUang spanned to x=1120, i.e.
## 40px off-screen entirely; and DisplayUang and DailyLogin sat centred
## on the two front-row students' heads (x~845 y~389 and x~225 y~389).

const SCREEN_W := 1080.0
const SCREEN_H := 1920.0
const RIM_CLEARANCE := 24.0

const SCENE := "res://Scenes/Lobby/loby.tscn"

const NAV_TILES := ["Koperasi", "Inventory", "ReportStudent"]


func suite_name() -> String:
	return "lobby_layout"


func _rects() -> Dictionary:
	# Source-text scan rather than instantiation: the lobby pulls in
	# shaders, autoload state and layered face rigs, and cannot be stood
	# up headlessly. This follows the project's established pattern.
	var src := FileAccess.get_file_as_string(SCENE)
	var out := {}
	var name := ""
	var r := {}
	for line in src.split("\n"):
		if line.begins_with("[node "):
			if name != "" and r.has("l") and r.has("r"):
				out[name] = r
			name = line.get_slice("name=\"", 1).get_slice("\"", 0)
			r = {}
		elif line.begins_with("offset_left = "):
			r["l"] = float(line.get_slice("= ", 1))
		elif line.begins_with("offset_right = "):
			r["r"] = float(line.get_slice("= ", 1))
		elif line.begins_with("offset_top = "):
			r["t"] = float(line.get_slice("= ", 1))
		elif line.begins_with("offset_bottom = "):
			r["b"] = float(line.get_slice("= ", 1))
	if name != "" and r.has("l") and r.has("r"):
		out[name] = r
	return out


func test_nav_tiles_share_one_height_and_one_baseline() -> void:
	var rects := _rects()
	var heights := []
	var tops := []
	for n in NAV_TILES:
		assert_true(rects.has(n), "lobby is missing node: " + n)
		heights.append(rects[n]["b"] - rects[n]["t"])
		tops.append(rects[n]["t"])
	for i in range(1, heights.size()):
		assert_eq(heights[i], heights[0],
			"%s height %f differs from %s height %f -- the three tiles are one row"
				% [NAV_TILES[i], heights[i], NAV_TILES[0], heights[0]])
		assert_eq(tops[i], tops[0],
			"%s top %f differs from %s top %f -- they must share a baseline"
				% [NAV_TILES[i], tops[i], NAV_TILES[0], tops[0]])


func test_nothing_clips_the_screen_rim() -> void:
	var rects := _rects()
	var offenders := []
	for name in rects:
		var r: Dictionary = rects[name]
		if not (r.has("l") and r.has("r")):
			continue
		# The full-bleed backdrop and card layers are meant to overhang.
		if name in ["Backdrop", "BGLayer", "ColorRect", "TutorialOverlay"]:
			continue
		if r["l"] < RIM_CLEARANCE or r["r"] > SCREEN_W - RIM_CLEARANCE:
			offenders.append("%s spans %f..%f" % [name, r["l"], r["r"]])
	assert_eq(offenders.size(), 0,
		"lobby controls within %fpx of the rim:\n  " % RIM_CLEARANCE
			+ "\n  ".join(offenders))


func test_hud_does_not_sit_on_the_front_row_faces() -> void:
	# Front-row head centres, derived from the portrait art's opaque
	# bounds (Thea.png: art starts 10.8% down, centred 49.9% across)
	# mapped through Slot3 and Slot4's rects.
	var heads := [Vector2(225, 389), Vector2(845, 389)]
	var radius := 110.0
	var rects := _rects()
	for name in ["DisplayUang", "DailyLogin"]:
		assert_true(rects.has(name), "lobby is missing node: " + name)
		var r: Dictionary = rects[name]
		for head in heads:
			var overlaps := head.x + radius > r["l"] and head.x - radius < r["r"] \
				and head.y + radius > r["t"] and head.y - radius < r["b"]
			assert_true(not overlaps,
				"%s (%f..%f, %f..%f) covers a student's head at %s"
					% [name, r["l"], r["r"], r["t"], r["b"], str(head)])
```

- [ ] **Step 2: Run it to verify it fails**

```
filesystem_manage(op="scan")
test_run(suite="lobby_layout")
```

Expected: FAIL on all three — differing tile heights (135/144/140),
`ReportStudent spans 709..1059` and `DisplayUang spans 831..1120.78`, and both
HUD nodes covering a head.

- [ ] **Step 3: Build the two lobby variations**

In `_build_buttons`, replacing the `LobbyNavButton` call:

```gdscript
	# The lobby's three destination tiles. Icon stacked over label: at
	# the L step there is room for a 64px icon, an 8px gap and a
	# font_title line inside the 120px content box, and the icon is what
	# makes a destination scannable. Retired LobbyNavButton, which was
	# one variation stretched across five boxes of five different sizes.
	_add_button_variation(theme, tokens, "LobbyNavTile",
		tokens.brand_primary_light, tokens.brand_primary_dark,
		tokens.outline_card, tokens.text_on_brand)
	theme.set_constant("icon_max_width", "LobbyNavTile", tokens.btn_icon_m)
	theme.set_constant("h_separation", "LobbyNavTile", 8)

	# The week's primary call to action. Horizontal rather than stacked:
	# it is 984px wide, and a stacked icon in a banner that shape leaves
	# exactly the horizontal emptiness this pass exists to remove.
	_add_button_variation(theme, tokens, "LobbyCtaButton",
		tokens.brand_primary_light, tokens.brand_primary_dark,
		tokens.outline_card, tokens.text_on_brand)
	theme.set_font_size("font_size", "LobbyCtaButton", tokens.font_h1)
	theme.set_constant("icon_max_width", "LobbyCtaButton", tokens.btn_icon_l)
	theme.set_constant("h_separation", "LobbyCtaButton", 24)
```

Vertical icon-over-text stacking is a `Button` property, not a theme one — set
`vertical_icon_alignment` and `icon_alignment` per node in step 4.

- [ ] **Step 4: Apply the layout in the editor**

```
scene_open(path="res://Scenes/Lobby/loby.tscn")
```

Set each node with `node_set_property`, then `scene_save()` once at the end.
Unquoted numbers.

| Node | left | top | right | bottom |
|---|---|---|---|---|
| `JUDUL` | 381 | 40 | 704 | 140 |
| `DailyLogin` | 48 | 1392 | 144 | 1488 |
| `DisplayUang` | 700 | 1301 | 1032 | 1488 |
| `Student` | 48 | 1520 | 1032 | 1680 |
| `Jadwal` | 48 | 1520 | 1032 | 1680 |
| `Koperasi` | 48 | 1712 | 354 | 1872 |
| `Inventory` | 386 | 1712 | 692 | 1872 |
| `ReportStudent` | 724 | 1712 | 1030 | 1872 |

`DisplayUang` is **332×187, not 332×96**. Its texture
(`Desain tanpa judul.png`) is 1920×1080 — aspect 1.78 — and a 96px-tall chip
would be aspect 3.46 and visibly stretch it. 187 preserves the art's aspect, so
the strip starts at y 1301 rather than 1392.

Then per node:

- `Koperasi`, `Inventory`, `ReportStudent`: `theme_type_variation` →
  `LobbyNavTile`, `icon` → the matching `Assets/Images/UI/Nav/` texture,
  `vertical_icon_alignment` → `0` (top), `icon_alignment` → `1` (center),
  `expand_icon` → `true`. Clear `custom_minimum_size` so the theme supplies the
  height.
- `ReportStudent`: `text` → `"Rapor"`. `"REPORT STUDENT"` does not fit a 306px
  tile at `font_title`, and Rapor is the correct Indonesian term regardless.
  **Leave the node name as `ReportStudent`** — `loby.gd:457`'s tutorial step
  targets it by name, and renaming the node breaks that string silently.
- `Student`, `Jadwal`: `theme_type_variation` → `LobbyCtaButton`, `icon` →
  `icon_cta_student.png` / `icon_cta_jadwal.png`, `icon_alignment` → `0` (left).

- [ ] **Step 5: Remove the two lobby entries from `HEIGHT_ALLOWED`**

Task 7 allow-listed `Student` and `Jadwal` at 267/290 pending this task. Both
are now 160, so delete both entries from `tests/test_button_geometry.gd`. An
exemption left behind after its reason is gone hides the next real one.

- [ ] **Step 6: Rebake and run everything**

```
filesystem_manage(op="scan")
test_run(suite="theme_rebake")
test_run()
```

Expected: fully green — including `theme_factory`, whose roster has been red
since Task 4 waiting for these two variations.

Then check `git diff HEAD -- '*.gd'`. The `scene_save` in step 4 may have
flushed stale script buffers; revert any `.gd` you did not intend to touch.

- [ ] **Step 7: Confirm visually**

```
project_run()
```

Seed and teleport rather than playing to the lobby: the debug overlay's
**⚡ Seed Playtest State** then its **Scenes** tab. Confirm the three tiles read
as one row, nothing clips the rim, and neither HUD chip touches a face.

- [ ] **Step 8: Commit**

```bash
git add Scenes/Lobby/loby.tscn Scripts/Design/ThemeFactory.gd tests/test_lobby_layout.gd tests/test_button_geometry.gd Assets/Theme/kejartes_theme.tres
git commit -m "feat(lobby): bottom HUD strip and a real nav tile row

Retires LobbyNavButton -- one variation stretched across five boxes of
five different sizes -- for LobbyNavTile (icon over label, L step) and
LobbyCtaButton (icon beside label, the 984px banner).

Moves DisplayUang and DailyLogin off the front-row students' heads into
a strip above the CTA. Both were centred on a face: the heads sit at
x~225 and x~845, y~389, derived from the portrait art's opaque bounds.
DisplayUang was also 40px off-screen, and is sized 332x187 rather than
332x96 so its 16:9 texture is not stretched.

ReportStudent's label becomes Rapor to fit a 306px tile; the node keeps
its name because loby.gd's tutorial targets it by string."
```

---

## Task 12: Verify the two unguarded risks

Both are visual, neither is covered by a test, and both were flagged in the
spec's risk section. This task exists so they are not skipped by a green suite.

**Files:** none — this is a verification pass.

- [ ] **Step 1: Check the `brand_primary` washes**

Nine screens use `brand_primary` as a low-alpha wash, tint or focus ring rather
than a button fill — including the event-row highlight noted at
`tests/test_result_checkup.gd:847`. `#7A4A2B` is far darker than `#2e5bff`, so
compositing it at low alpha over a light surface reads **muddy**, not warm.

```
grep -rn "brand_primary" --include=*.gd Scripts/ | grep -v Design/
```

Open each result's screen and look at it. Where a wash reads muddy, raise its
alpha or switch it to `brand_primary_light`; do not change the token.

- [ ] **Step 2: Check the five day tints**

`SchoolDay.gd:321` lerps `surface_page` toward each day's category accent, and
`SimulationBackground.gd` starts its fill from it. Moving `surface_page` from
`#eef3ff` to `#FBF1E3` changes what all five resolve to — a cool page lerped
toward red is a different colour than a cream one.

Seed, teleport to SchoolDay, and step through all five days. If any reads
wrong, adjust `SchoolDay.gd`'s mix ratio rather than `surface_page`, which now
has many other consumers.

- [ ] **Step 3: Record what you found**

Append findings to the spec's Known risk section — resolved, or still open with
what remains. Do not delete the section; the next palette change will hit the
same two places.

- [ ] **Step 4: Full suite and commit**

```
test_run()
```

```bash
git add -A
git commit -m "docs(design): record the outcome of the warm-UI risk pass

The brand_primary washes and the five SchoolDay day tints are the two
things a green suite cannot confirm, so both were checked by eye."
```

---

## Self-Review

**Spec coverage.** Walked Part 1 section by section. Token changes → Task 1.
New exports → Task 1. Editor restart → Task 2. `_button_box` and the radius
table → Task 3. The four bypassers → Task 3 step 6. Size steps → Task 4.
`DISPLAY_ROSTER` including the `LobbyNavButton` removal → Task 4 step 4.
Derived padding → Task 5. On-dark bar switch → Task 6. Contrast guard → Task 6.
Natural-height test → Task 5. Height ratchet → Task 7. Icons → Task 8. The
`menu_button.png` split → Tasks 8 and 9. `DisplayUang` aspect → Task 11 step 4.
`DailyReward` anchors → Task 10. Lobby geometry test → Task 11. `brand_primary`
and `surface_page` risks → Task 12. No gaps found.

**Placeholders.** Three deliberate `<...>` markers remain, all of them values
that *cannot* be known in advance and each with a step that derives it: the
solved `btn_pad_v` numbers (Task 5 step 3), `menu_button.png`'s region and
margins (Task 8 step 2, consumed in Task 9 step 3), and `DailyReward`'s saved
rect (Task 10 step 2, consumed in step 3). Writing invented numbers for any of
these would be worse than marking them.

**Type consistency.** `_button_box` takes `(tokens, top, bottom, border,
shadow_dy, radius)` in Task 3 and is called with six arguments in every later
reference. `_add_button_variation`'s trailing `radius: int = -1` matches its
three explicit call sites in Task 3 step 5. `_add_size_step(theme, tokens, base,
suffix, font_size, pad_v)` matches its two loops in Task 4 step 3.
`category_color_on_dark` is defined in Task 1 step 5 and consumed in Task 6 step
1. Variation names are spelled identically in `SIZE_STEPS`, `DISPLAY_ROSTER`
and the `_add_size_step` loops.

**One intentional red window.** `DISPLAY_ROSTER` lists `LobbyNavTile` and
`LobbyCtaButton` from Task 4 but they are not built until Task 11, so
`test_theme_factory` fails across Tasks 4–10. This is flagged at both ends. The
alternative — adding them to the roster in Task 11 — makes it possible to build
the variations and forget the roster, which is the exact failure mode the
roster's own doc comment says it exists to prevent.
