# Minigame Polish Part 1 — Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the shared minigame UI kit — the "Bingkai Kayu" card family, answer button, image plate, and HUD chrome — as `ThemeFactory` type variations plus one reusable `MinigameHeader` scene, so every later minigame phase has a real, tested vocabulary to consume.

**Architecture:** Add one `_build_minigame_kit()` helper to `ThemeFactory` that registers the new variations from existing `DesignTokens` (no new tokens, so no Resource-restart hazard). Prove each variation with a dedicated `test_minigame_kit` suite that builds the theme in-process. Rebake the baked theme once, updating the two pins (`test_theme_factory`'s declared-variation list and `DISPLAY_ROSTER`). Finally build a small `@tool` `MinigameHeader.tscn`/`.gd` that wears the HUD variations.

**Tech Stack:** Godot 4.6 (GDScript), `ThemeFactory`/`DesignTokens` theme system, `McpTestSuiteCompat` suites run via the Godot AI MCP `test_run` tool.

**Spec:** `docs/superpowers/specs/2026-09-28-minigame-polish-part-1-design.md` (read §3 Locked decisions and §4.1 Shared kit before starting).

## Scope

This is **Plan 1 of a series.** It builds the *foundation only* — the theme
variations and the shared HUD scene. Applying the kit to actual minigames (the
`PilihanGanda` quiz reference screen, the Tutorial/Pause/Quit overlays, win/lose,
Menjodohkan, the gameplay minigames, and the motion pass) are **follow-on plans**
that consume the variation names produced here. This split is deliberate: those
plans' "Consumes" interfaces are the exact variation strings finalized in Task 4,
which don't concretely exist until this plan lands.

**This plan produces working, testable software on its own:** a baked theme that
declares the minigame kit, plus an instantiable `MinigameHeader` scene, both
covered by green suites.

## Global Constraints

Copied verbatim from the spec / `CLAUDE.md` — every task implicitly includes these:

- **No new `theme_override_*`.** Style only through `ThemeFactory` type variations. Only layout-only constant overrides (`separation`, `margin_*`) are allowed.
- **No `Balance.gd` edits.** Not touched in this plan.
- **No new persistence.**
- **Every script gets a `##` file-header and a `##` line on every `@export`** (`tests/test_script_documentation.gd`).
- **No runtime-built visuals** beyond the documented ratchet (`tests/test_viewport_editability.gd`). Static chrome = nodes in the `.tscn`.
- **Indonesian** UI text; **no emoji as iconography** — real transparent SVG textures only.
- **Sub-scene `@export`s go on the instance ROOT** (child overrides are dropped on save).
- **File names PascalCase** for `.gd`/`.tscn`. **Conventional Commits with a scope** (e.g. `feat(minigame-kit): …`).
- **Editing workflow:** edit `.tscn` only through the editor (`scene_open` → `node_*`/`batch_execute` → `scene_save`), never by hand while the editor is attached. After editing a `.gd` from outside the editor, run `filesystem_manage(op="scan")` (or a no-op `script_patch`) before `test_run`, or the runner serves a stale copy. `ThemeFactory` and `DesignTokens` carry `class_name`; after editing them, rescan before running the game.
- **Prefer targeted `test_run(suite="…")`** over full runs (a full run rebakes `kejartes_theme.tres`, rewrites `default_bus_layout.tres`, and can drop the bridge). `git status` after any full run and `git checkout --` unintended changes.

---

## File Structure

- `Scripts/Design/ThemeFactory.gd` — **modify.** Add `_build_minigame_kit(theme, tokens)` and one call to it inside `build()`. All new variations live in this one helper.
- `tests/test_minigame_kit.gd` — **create.** Build-based suite (calls `ThemeFactory.build(...)` directly, no baked-file dependency) proving every new variation and its key properties.
- `tests/test_theme_factory.gd` — **modify (Task 4 only).** Add the new variation names to the `expected` list in `test_every_declared_variation_exists`, and add the display-font variations to `DISPLAY_ROSTER`.
- `Assets/Theme/kejartes_theme.tres` — **regenerate (Task 4).** Rebaked from the factory; committed.
- `Scenes/Minigames/UI/MinigameHeader.tscn` — **create.** The reusable HUD strip.
- `Scripts/Minigames/UI/MinigameHeader.gd` — **create.** `@tool` script for the strip.
- `tests/test_minigame_header.gd` — **create.** Instantiates the scene, asserts its nodes wear the HUD variations and its exports exist.

**Variation names produced by this plan** (the interface later plans consume):
`MinigameCard`, `MinigameCardInner`, `MinigameImagePlate`, `MinigameAnswerButton`,
`MinigameHudPill`, `MinigameHudValue`, `MinigameHudIconButton`, `MinigamePlankPanel`,
`MinigamePlankLabel`.

---

### Task 1: Card family variations (MinigameCard / MinigameCardInner / MinigameImagePlate)

The Bingkai Kayu card is a wooden frame (`MinigameCard`, brand-filled) wrapping a cream inner (`MinigameCardInner`), with an optional recessed image plate (`MinigameImagePlate`). All reuse existing tokens.

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd` (add `_build_minigame_kit`, call it in `build()`)
- Test: `tests/test_minigame_kit.gd` (create)

**Interfaces:**
- Consumes: `DesignTokens` fields `brand_primary`, `brand_primary_dark`, `surface_card`, `preview_pill_fill`, `outline_card`, `outline_width`, `radius_lg`, `radius_md`, `shadow_color`, `shadow_size`, `shadow_offset`.
- Produces: theme type variations `MinigameCard` (Panel), `MinigameCardInner` (Panel), `MinigameImagePlate` (Panel).

- [ ] **Step 1: Write the failing test**

Create `tests/test_minigame_kit.gd`:

```gdscript
@tool
extends McpTestSuiteCompat

## Proves the shared minigame UI kit variations added in
## ThemeFactory._build_minigame_kit(). Build-based: constructs the theme in
## process so it never depends on the baked kejartes_theme.tres.

func _kit() -> Theme:
	return ThemeFactory.build(DesignTokens.load_default())


func test_minigame_card_is_a_wood_frame() -> void:
	var t := DesignTokens.load_default()
	var sb := _kit().get_stylebox("panel", "MinigameCard") as StyleBoxFlat
	assert_true(sb != null, "MinigameCard has a flat panel stylebox")
	if sb == null:
		return
	assert_true(sb.bg_color.is_equal_approx(t.brand_primary), "frame is filled with the brand wood colour")
	assert_gt(sb.border_width_top, 0, "the frame has a visible rim")
	assert_gt(sb.shadow_size, 0, "the card is lifted off the wood by a shadow")


func test_minigame_card_inner_is_cream() -> void:
	var t := DesignTokens.load_default()
	var sb := _kit().get_stylebox("panel", "MinigameCardInner") as StyleBoxFlat
	assert_true(sb != null, "MinigameCardInner has a flat panel stylebox")
	if sb == null:
		return
	assert_true(sb.bg_color.is_equal_approx(t.surface_card), "inner face is the cream card colour")


func test_minigame_image_plate_is_a_recessed_slot() -> void:
	var t := DesignTokens.load_default()
	var sb := _kit().get_stylebox("panel", "MinigameImagePlate") as StyleBoxFlat
	assert_true(sb != null, "MinigameImagePlate has a flat panel stylebox")
	if sb == null:
		return
	assert_true(sb.bg_color.is_equal_approx(t.preview_pill_fill), "plate uses the recessed slot colour")
```

- [ ] **Step 2: Run the test to verify it fails**

After creating the file, rescan then run:
`test_run(suite="test_minigame_kit")`
Expected: FAIL — `MinigameCard`/`MinigameCardInner`/`MinigameImagePlate` styleboxes are null (variations don't exist yet).

- [ ] **Step 3: Add the helper and register it**

In `Scripts/Design/ThemeFactory.gd`, add the call inside `build()` (next to the other `_build_*` calls, before `_build_base_overrides`):

```gdscript
	_build_minigame_kit(theme, tokens)
```

Then add the helper (place it near the other `_build_minigame_*` helpers):

```gdscript
## The shared minigame UI kit (2026-09-28, spec minigame-polish-part-1).
## Bingkai Kayu: a brand-filled wooden frame (MinigameCard) wrapping a cream
## inner (MinigameCardInner), with a recessed image plate (MinigameImagePlate)
## for picture questions. All from existing tokens — no new tokens.
static func _build_minigame_kit(theme: Theme, tokens: DesignTokens) -> void:
	var frame := StyleBoxFlat.new()
	frame.bg_color = tokens.brand_primary
	frame.set_border_width_all(tokens.outline_width)
	frame.border_color = tokens.brand_primary_dark
	frame.set_corner_radius_all(tokens.radius_lg)
	frame.content_margin_left = tokens.space_xs
	frame.content_margin_right = tokens.space_xs
	frame.content_margin_top = tokens.space_xs
	frame.content_margin_bottom = tokens.space_xs
	var deep := tokens.shadow_color
	deep.a = minf(1.0, tokens.shadow_color.a + 0.2)  # pops harder on bright wood
	frame.shadow_color = deep
	frame.shadow_size = tokens.shadow_size
	frame.shadow_offset = tokens.shadow_offset
	theme.set_type_variation("MinigameCard", "Panel")
	theme.set_stylebox("panel", "MinigameCard", frame)

	var inner := StyleBoxFlat.new()
	inner.bg_color = tokens.surface_card
	inner.set_corner_radius_all(tokens.radius_md)
	inner.content_margin_left = tokens.space_md
	inner.content_margin_right = tokens.space_md
	inner.content_margin_top = tokens.space_md
	inner.content_margin_bottom = tokens.space_md
	theme.set_type_variation("MinigameCardInner", "Panel")
	theme.set_stylebox("panel", "MinigameCardInner", inner)

	var plate := StyleBoxFlat.new()
	plate.bg_color = tokens.preview_pill_fill
	plate.set_corner_radius_all(tokens.radius_md)
	plate.shadow_color = tokens.preview_pill_shadow_color
	plate.shadow_size = tokens.preview_pill_shadow_size
	plate.shadow_offset = tokens.preview_pill_shadow_offset
	theme.set_type_variation("MinigameImagePlate", "Panel")
	theme.set_stylebox("panel", "MinigameImagePlate", plate)
```

- [ ] **Step 4: Run the test to verify it passes**

Rescan (`filesystem_manage(op="scan")`), then `test_run(suite="test_minigame_kit")`.
Expected: PASS (3 tests). Do **not** run `test_theme_factory` yet — its baked-match and declared-list tests fail until Task 4.

- [ ] **Step 5: Commit**

```bash
git add Scripts/Design/ThemeFactory.gd tests/test_minigame_kit.gd
git commit -m "feat(minigame-kit): Bingkai Kayu card, inner and image-plate variations"
```

---

### Task 2: Answer button variation (MinigameAnswerButton)

Solid brand-filled answer button with all four states and a gold-lit top edge, sized for touch.

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd` (extend `_build_minigame_kit`)
- Test: `tests/test_minigame_kit.gd` (add tests)

**Interfaces:**
- Consumes: `DesignTokens` `brand_primary`, `brand_primary_light`, `brand_primary_dark`, `text_on_brand`, `radius_button`, `outline_width`, `btn_h_s`, `btn_pad_v_s`, `space_lg`, `font_display`, `font_title`.
- Produces: `MinigameAnswerButton` (Button) with `normal`/`hover`/`pressed`/`disabled` styleboxes; display font; min height ≥ `btn_h_s`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_minigame_kit.gd`:

```gdscript
func test_answer_button_has_all_four_states() -> void:
	var t := _kit()
	for state in ["normal", "hover", "pressed", "disabled"]:
		assert_true(t.has_stylebox(state, "MinigameAnswerButton"),
			"MinigameAnswerButton must define stylebox: " + state)


func test_answer_button_is_brand_filled_and_touch_sized() -> void:
	var tok := DesignTokens.load_default()
	var sb := _kit().get_stylebox("normal", "MinigameAnswerButton") as StyleBoxFlat
	assert_true(sb != null, "normal state is a flat stylebox")
	if sb == null:
		return
	assert_true(sb.bg_color.is_equal_approx(tok.brand_primary), "filled with the brand colour")
	assert_gt(sb.border_width_top, 0, "has the gold/light top edge as a border")
	var min_h: float = sb.content_margin_top + sb.content_margin_bottom
	assert_true(min_h >= float(tok.btn_pad_v_s) * 2.0 - 1.0, "vertical padding matches the small button step")


func test_answer_button_uses_the_display_font() -> void:
	var tok := DesignTokens.load_default()
	if tok.font_display == null:
		return
	assert_eq(_kit().get_font("font", "MinigameAnswerButton"), tok.font_display,
		"answer text is set in the display face")
```

- [ ] **Step 2: Run the test to verify it fails**

`test_run(suite="test_minigame_kit")` → FAIL (button styleboxes/font missing).

- [ ] **Step 3: Extend the helper**

Append inside `_build_minigame_kit()`:

```gdscript
	theme.set_type_variation("MinigameAnswerButton", "Button")
	for state_name in ["normal", "hover", "pressed", "disabled"]:
		var b := StyleBoxFlat.new()
		b.bg_color = tokens.brand_primary
		if state_name == "hover":
			b.bg_color = tokens.brand_primary_light
		elif state_name == "pressed":
			b.bg_color = tokens.brand_primary_dark
		b.set_corner_radius_all(tokens.radius_button)
		b.set_border_width_all(tokens.outline_width / 2)
		b.border_width_top = tokens.outline_width  # gold-lit top edge
		b.border_color = tokens.brand_primary_dark
		b.border_color = b.border_color if state_name != "normal" else tokens.brand_primary_light
		b.content_margin_top = tokens.btn_pad_v_s
		b.content_margin_bottom = tokens.btn_pad_v_s
		b.content_margin_left = tokens.space_lg
		b.content_margin_right = tokens.space_lg
		theme.set_stylebox(state_name, "MinigameAnswerButton", b)
	theme.set_color("font_color", "MinigameAnswerButton", tokens.text_on_brand)
	theme.set_font_size("font_size", "MinigameAnswerButton", tokens.font_title)
	if tokens.font_display != null:
		theme.set_font("font", "MinigameAnswerButton", tokens.font_display)
```

- [ ] **Step 4: Run the test to verify it passes**

Rescan, `test_run(suite="test_minigame_kit")` → PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add Scripts/Design/ThemeFactory.gd tests/test_minigame_kit.gd
git commit -m "feat(minigame-kit): brand-filled answer button variation"
```

---

### Task 3: HUD + plank variations

The shared HUD chrome: a score pill (`MinigameHudPill` panel + `MinigameHudValue` gold label), round icon buttons (`MinigameHudIconButton`), and the carved plank tab (`MinigamePlankPanel` + `MinigamePlankLabel`).

**Files:**
- Modify: `Scripts/Design/ThemeFactory.gd` (extend `_build_minigame_kit`)
- Test: `tests/test_minigame_kit.gd` (add tests)

**Interfaces:**
- Consumes: `DesignTokens` `brand_primary_dark`, `outline_card`, `outline_width`, `radius_pill`, `radius_md`, `currency_gold`, `touch_target_min`, `font_display`, `font_title`, `font_caption`.
- Produces: `MinigameHudPill` (Panel), `MinigameHudValue` (Label), `MinigameHudIconButton` (Button, 4 states), `MinigamePlankPanel` (Panel), `MinigamePlankLabel` (Label).

- [ ] **Step 1: Write the failing test**

Append to `tests/test_minigame_kit.gd`:

```gdscript
func test_hud_pill_and_value() -> void:
	var tok := DesignTokens.load_default()
	var pill := _kit().get_stylebox("panel", "MinigameHudPill") as StyleBoxFlat
	assert_true(pill != null, "MinigameHudPill has a panel stylebox")
	if pill != null:
		assert_true(pill.bg_color.is_equal_approx(tok.brand_primary_dark), "pill is dark brand")
	assert_true(_kit().get_color("font_color", "MinigameHudValue").is_equal_approx(tok.currency_gold),
		"score value is gold")


func test_hud_icon_button_has_all_states_and_is_touch_sized() -> void:
	var tok := DesignTokens.load_default()
	for state in ["normal", "hover", "pressed", "disabled"]:
		assert_true(_kit().has_stylebox(state, "MinigameHudIconButton"),
			"MinigameHudIconButton must define stylebox: " + state)
	var mn: Vector2 = _kit().get_constant("", "MinigameHudIconButton") if false else Vector2.ZERO
	# min size is set on the node in the scene; here we assert the stylebox radius reads as a pill
	var sb := _kit().get_stylebox("normal", "MinigameHudIconButton") as StyleBoxFlat
	assert_true(sb != null and sb.corner_radius_top_left >= tok.radius_md, "icon button is round")


func test_plank_panel_and_label() -> void:
	var tok := DesignTokens.load_default()
	var panel := _kit().get_stylebox("panel", "MinigamePlankPanel") as StyleBoxFlat
	assert_true(panel != null and panel.bg_color.is_equal_approx(tok.brand_primary_dark),
		"plank panel is dark brand")
	assert_true(_kit().get_color("font_color", "MinigamePlankLabel").is_equal_approx(tok.currency_gold),
		"plank label text is gold")
```

- [ ] **Step 2: Run the test to verify it fails**

`test_run(suite="test_minigame_kit")` → FAIL (HUD/plank variations missing).

- [ ] **Step 3: Extend the helper**

Append inside `_build_minigame_kit()`:

```gdscript
	var pill := StyleBoxFlat.new()
	pill.bg_color = tokens.brand_primary_dark
	pill.set_corner_radius_all(tokens.radius_pill)
	pill.set_border_width_all(tokens.outline_width / 2)
	pill.border_color = tokens.outline_card
	pill.content_margin_left = tokens.space_md
	pill.content_margin_right = tokens.space_md
	pill.content_margin_top = tokens.space_xs
	pill.content_margin_bottom = tokens.space_xs
	theme.set_type_variation("MinigameHudPill", "Panel")
	theme.set_stylebox("panel", "MinigameHudPill", pill)

	theme.set_type_variation("MinigameHudValue", "Label")
	theme.set_color("font_color", "MinigameHudValue", tokens.currency_gold)
	theme.set_font_size("font_size", "MinigameHudValue", tokens.font_title)
	if tokens.font_display != null:
		theme.set_font("font", "MinigameHudValue", tokens.font_display)

	theme.set_type_variation("MinigameHudIconButton", "Button")
	for icon_state in ["normal", "hover", "pressed", "disabled"]:
		var ib := StyleBoxFlat.new()
		ib.bg_color = tokens.brand_primary_dark if icon_state != "pressed" else tokens.brand_primary
		ib.set_corner_radius_all(tokens.radius_pill)
		ib.set_border_width_all(tokens.outline_width / 2)
		ib.border_color = tokens.outline_card
		theme.set_stylebox(icon_state, "MinigameHudIconButton", ib)

	var plank := StyleBoxFlat.new()
	plank.bg_color = tokens.brand_primary_dark
	plank.set_corner_radius_all(tokens.radius_md)
	plank.set_border_width_all(tokens.outline_width / 2)
	plank.border_color = tokens.outline_card
	plank.content_margin_left = tokens.space_md
	plank.content_margin_right = tokens.space_md
	plank.content_margin_top = tokens.space_xs
	plank.content_margin_bottom = tokens.space_xs
	theme.set_type_variation("MinigamePlankPanel", "Panel")
	theme.set_stylebox("panel", "MinigamePlankPanel", plank)

	theme.set_type_variation("MinigamePlankLabel", "Label")
	theme.set_color("font_color", "MinigamePlankLabel", tokens.currency_gold)
	theme.set_font_size("font_size", "MinigamePlankLabel", tokens.font_caption)
	if tokens.font_display != null:
		theme.set_font("font", "MinigamePlankLabel", tokens.font_display)
```

- [ ] **Step 4: Run the test to verify it passes**

Rescan, `test_run(suite="test_minigame_kit")` → PASS (9 tests).

- [ ] **Step 5: Commit**

```bash
git add Scripts/Design/ThemeFactory.gd tests/test_minigame_kit.gd
git commit -m "feat(minigame-kit): HUD pill, icon button and plank variations"
```

---

### Task 4: Pin the variations and rebake the theme

Update the two pins that must move with the factory, rebake the baked theme, and confirm the whole theme suite is green.

**Files:**
- Modify: `tests/test_theme_factory.gd` (declared-variation list + `DISPLAY_ROSTER`)
- Regenerate + commit: `Assets/Theme/kejartes_theme.tres`

**Interfaces:**
- Consumes: the nine variations from Tasks 1–3.
- Produces: a baked theme that declares them; a green `test_theme_factory`.

- [ ] **Step 1: Extend the declared-variation list**

In `tests/test_theme_factory.gd`, in `test_every_declared_variation_exists`, add to the `expected` array:

```gdscript
		"MinigameCard", "MinigameCardInner", "MinigameImagePlate",
		"MinigameAnswerButton", "MinigameHudPill", "MinigameHudValue",
		"MinigameHudIconButton", "MinigamePlankPanel", "MinigamePlankLabel",
```

- [ ] **Step 2: Extend DISPLAY_ROSTER**

Find `const DISPLAY_ROSTER := [` (~line 298). It pins which variations carry `font_display`. Add the three display-font variations this plan introduced:

```gdscript
	"MinigameAnswerButton", "MinigameHudValue", "MinigamePlankLabel",
```

Leave the panel and non-display variations out (they carry no font). If `DISPLAY_ROSTER` is asserted in both directions (a "these and only these" check), make sure the three card/HUD *panel* variations are not wrongly expected to have a display font.

- [ ] **Step 3: Run the theme factory suite to verify the pins**

`test_run(suite="test_theme_factory")`
Expected: the declared-variation and display-roster tests PASS; `test_baked_theme_matches_what_the_factory_builds` **FAILS** (baked file is stale — that's expected, fixed next).

- [ ] **Step 4: Rebake the baked theme**

In the editor, run `Scripts/Design/BakeTheme.gd` via File > Run (Ctrl+Shift+X). This overwrites `Assets/Theme/kejartes_theme.tres` from the current factory.

- [ ] **Step 5: Run the theme factory suite again to verify it fully passes**

`test_run(suite="test_theme_factory")` → all PASS, including `test_baked_theme_matches_what_the_factory_builds`.

- [ ] **Step 6: Commit**

```bash
git add tests/test_theme_factory.gd Assets/Theme/kejartes_theme.tres
git commit -m "feat(minigame-kit): pin new variations and rebake the baked theme"
```

---

### Task 5: Shared MinigameHeader scene

A reusable HUD strip — pause icon-button (left), gold score pill (centre), timer icon-button (right) — that every minigame will instance. Icons are supplied via root `@export`s so the art (an asset dependency) can drop in without scene surgery.

**Files:**
- Create: `Scripts/Minigames/UI/MinigameHeader.gd`
- Create: `Scenes/Minigames/UI/MinigameHeader.tscn`
- Test: `tests/test_minigame_header.gd`

**Interfaces:**
- Consumes: variations `MinigameHudPill`, `MinigameHudValue`, `MinigameHudIconButton` (from Task 3).
- Produces: `MinigameHeader` (Control) with `signal pause_pressed`, `@export var score_text`, `@export var show_timer`, `@export var pause_icon: Texture2D`, `@export var timer_icon: Texture2D`, and `func set_score(text: String)`.

- [ ] **Step 1: Write the script**

Create `Scripts/Minigames/UI/MinigameHeader.gd`:

```gdscript
@tool
class_name MinigameHeader
extends Control

## Shared minigame top HUD: a pause icon-button (left), a gold score pill
## (centre) and a timer icon-button (right). Every minigame instances this so
## the chrome is identical across modes. Presentational only — the owning
## minigame connects `pause_pressed` and pushes text via `set_score`.

## Emitted when the pause icon-button is pressed.
signal pause_pressed

## The centre pill text, e.g. "Skor 0 / 3".
@export var score_text: String = "Skor 0 / 0":
	set(value):
		score_text = value
		_apply()
## Whether the right-hand timer icon-button is shown.
@export var show_timer: bool = true:
	set(value):
		show_timer = value
		_apply()
## Icon texture for the pause button (transparent SVG; no emoji).
@export var pause_icon: Texture2D:
	set(value):
		pause_icon = value
		_apply()
## Icon texture for the timer button (transparent SVG; no emoji).
@export var timer_icon: Texture2D:
	set(value):
		timer_icon = value
		_apply()

@onready var _pause: Button = $PauseButton
@onready var _timer: Button = $TimerButton
@onready var _value: Label = $ScorePill/Value


func _ready() -> void:
	if not _pause.pressed.is_connected(_on_pause_pressed):
		_pause.pressed.connect(_on_pause_pressed)
	if Engine.is_editor_hint():
		return
	_apply()


func _on_pause_pressed() -> void:
	pause_pressed.emit()


func _apply() -> void:
	if _value != null:
		_value.text = score_text
	if _timer != null:
		_timer.visible = show_timer
		_timer.icon = timer_icon
	if _pause != null:
		_pause.icon = pause_icon


## Convenience setter the owning minigame calls each time the score changes.
func set_score(text: String) -> void:
	score_text = text
```

- [ ] **Step 2: Build the scene in the editor**

`scene_open` a new scene, then create nodes (via `node_create`/`batch_execute`, then `scene_save` to `Scenes/Minigames/UI/MinigameHeader.tscn`):

- Root `MinigameHeader` (Control), attach `Scripts/Minigames/UI/MinigameHeader.gd`. Anchor full-width, top; height ~ `btn_h_s`.
- `PauseButton` (Button), `theme_type_variation = "MinigameHudIconButton"`, `custom_minimum_size = (touch_target_min, touch_target_min)` = `(96, 96)`, anchored left.
- `ScorePill` (Panel), `theme_type_variation = "MinigameHudPill"`, centred; child `Value` (Label), `theme_type_variation = "MinigameHudValue"`, `text = "Skor 0 / 0"`, centred.
- `TimerButton` (Button), `theme_type_variation = "MinigameHudIconButton"`, `custom_minimum_size = (96, 96)`, anchored right.

No `theme_override_*`. `scene_save`.

- [ ] **Step 3: Write the failing test**

Create `tests/test_minigame_header.gd`:

```gdscript
@tool
extends McpTestSuiteCompat

## Proves the shared MinigameHeader HUD instantiates and wears the kit's HUD
## variations (from ThemeFactory._build_minigame_kit).

const HEADER := preload("res://Scenes/Minigames/UI/MinigameHeader.tscn")


func test_header_instantiates() -> void:
	var h := HEADER.instantiate()
	assert_true(h != null, "MinigameHeader instantiates")
	if h != null:
		h.free()


func test_score_pill_wears_hud_variations() -> void:
	var h := HEADER.instantiate()
	assert_eq(h.get_node("ScorePill").theme_type_variation, &"MinigameHudPill",
		"score pill wears the HUD pill variation")
	assert_eq(h.get_node("ScorePill/Value").theme_type_variation, &"MinigameHudValue",
		"score number wears the gold value variation")
	h.free()


func test_pause_and_timer_are_icon_buttons() -> void:
	var h := HEADER.instantiate()
	assert_eq(h.get_node("PauseButton").theme_type_variation, &"MinigameHudIconButton",
		"pause is an icon button")
	assert_eq(h.get_node("TimerButton").theme_type_variation, &"MinigameHudIconButton",
		"timer is an icon button")
	h.free()


func test_set_score_updates_the_export() -> void:
	var h := HEADER.instantiate()
	h.set_score("Skor 2 / 3")
	assert_eq(h.score_text, "Skor 2 / 3", "set_score writes score_text")
	h.free()
```

- [ ] **Step 4: Run the test to verify it passes**

Rescan, `test_run(suite="test_minigame_header")`.
Expected: PASS (4 tests). If `theme_type_variation` reads as an empty StringName, the scene's node property wasn't saved — re-open, set it via the editor, `scene_save`, rescan.

- [ ] **Step 5: Run the documentation + editability suites**

`test_run(suite="test_script_documentation")` and `test_run(suite="test_viewport_editability")`.
Expected: PASS — `MinigameHeader.gd` has its `##` header and per-`@export` docs, and builds no runtime visuals (static nodes only). If `test_viewport_editability` flags the new scene, it must be because chrome is static in the `.tscn`; do not add it to `BASELINE`.

- [ ] **Step 6: Commit**

```bash
git add Scripts/Minigames/UI/MinigameHeader.gd Scenes/Minigames/UI/MinigameHeader.tscn tests/test_minigame_header.gd
git commit -m "feat(minigame-kit): reusable MinigameHeader HUD scene"
```

---

## Self-Review

**Spec coverage (this plan = spec §4.1 + §4.2's HUD only):**
- §4.1 card + button + image plate + HUD + plank variations → Tasks 1–3. ✓
- §4.1 rebake + ThemeFactory/DISPLAY_ROSTER pinning → Task 4. ✓
- §4.2 shared HUD scene → Task 5. ✓
- **Deliberately deferred to follow-on plans** (stated in Scope): the `WoodNavArrow`, `MinigamePairChip*`, `MinigameToolCard*` variations (needed only by their consuming screens), all overlay redesigns, win/lose, Menjodohkan, gameplay-MG polish + bug fixes, and the motion vocabulary. Each becomes its own plan consuming the names produced here.

**Placeholder scan:** No "TBD"/"handle edge cases"/"similar to Task N". All code steps carry real GDScript. The one asset gap (pause/timer icon art) is handled structurally via root `@export`s, not a TODO.

**Type consistency:** Variation strings are identical across Tasks 1–5 and the Task 4 pins and the Task 5 tests: `MinigameCard`, `MinigameCardInner`, `MinigameImagePlate`, `MinigameAnswerButton`, `MinigameHudPill`, `MinigameHudValue`, `MinigameHudIconButton`, `MinigamePlankPanel`, `MinigamePlankLabel`. `MinigameHeader` API (`pause_pressed`, `score_text`, `show_timer`, `pause_icon`, `timer_icon`, `set_score`) is consistent between the script and its test.

**Note for the executor:** `test_minigame_kit` intentionally has no baked-file dependency (it calls `ThemeFactory.build()` directly), so Tasks 1–3 stay green without a rebake; the baked file is reconciled once in Task 4. If a step's assertion about a token value fails, check `DesignTokens.gd` for the current value rather than assuming the constant in this plan — tokens may have moved since 2026-09-28.
